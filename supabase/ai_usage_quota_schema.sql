-- ============================================================
-- غدير — حماية تكلفة AI (understand_turn فقط)
-- جدول عدّادات صغير + دالتان ذريتان. لا يخزّن نص المستخدم ولا هويته:
-- المفتاح المخزَّن = hash (SHA-256 مقتطع) لمفتاح الزائر/الـIP، ويُحذف يومياً بعد يومين.
-- Idempotent. لا يمس أي جدول أو سياسة قائمة.
-- نفّذه مرة واحدة في Supabase SQL Editor قبل نشر الدالة.
-- ============================================================

create table if not exists public.ai_usage_counters (
  scope text not null check (scope in ('visitor', 'ip', 'month')),
  key text not null,
  period text not null,               -- 'YYYY-MM-DD' (يومي) أو 'YYYY-MM' (شهري)، بتوقيت بغداد
  count integer not null default 0,
  tokens bigint not null default 0,   -- يُستخدم لصف month فقط
  updated_at timestamptz not null default now(),
  primary key (scope, key, period)
);

create index if not exists ai_usage_counters_period_idx
  on public.ai_usage_counters (period);

-- RLS مفعّل بلا أي سياسة: anon/authenticated لا يقرأون ولا يكتبون. service_role فقط.
alter table public.ai_usage_counters enable row level security;
revoke all on table public.ai_usage_counters from anon, authenticated;

-- يستهلك طلباً واحداً بشكل ذري. يرجع: 'ok' أو سبب الرفض:
--   visitor_daily | ip_daily | monthly | monthly_tokens
-- أي حد <= 0 يعني رفض كل الطلبات لذلك النطاق (وليس «بلا حد»).
-- عند الرفض لا يبقى أي عدّاد مزاد (تراجع كامل).
create or replace function public.ai_usage_consume(
  p_visitor text,
  p_ip text,
  p_visitor_day_limit integer,
  p_ip_day_limit integer,
  p_month_limit integer,
  p_month_token_limit bigint default 0
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_day text := to_char((now() at time zone 'Asia/Baghdad')::date, 'YYYY-MM-DD');
  v_month text := to_char((now() at time zone 'Asia/Baghdad')::date, 'YYYY-MM');
  n integer;
  used_tokens bigint;
begin
  if coalesce(p_month_limit, 0) <= 0 then return 'monthly'; end if;
  if coalesce(p_visitor_day_limit, 0) <= 0 then return 'visitor_daily'; end if;
  if coalesce(p_ip_day_limit, 0) <= 0 then return 'ip_daily'; end if;
  if p_visitor is null or length(p_visitor) < 8 or p_ip is null or length(p_ip) < 8 then
    return 'visitor_daily';
  end if;

  begin
    -- 1) سقف التوكنز الشهري (اختياري): مقارنة بما سُجّل فعلياً.
    if coalesce(p_month_token_limit, 0) > 0 then
      select tokens into used_tokens
      from public.ai_usage_counters
      where scope = 'month' and key = 'all' and period = v_month;
      if coalesce(used_tokens, 0) >= p_month_token_limit then
        raise exception 'quota_monthly_tokens';
      end if;
    end if;

    -- 2) الحد الشهري العام.
    insert into public.ai_usage_counters as c (scope, key, period, count)
    values ('month', 'all', v_month, 1)
    on conflict (scope, key, period) do update
      set count = c.count + 1, updated_at = now()
      where c.count < p_month_limit
    returning c.count into n;
    if n is null then raise exception 'quota_monthly'; end if;

    -- 3) الحد اليومي لكل زائر.
    n := null;
    insert into public.ai_usage_counters as c (scope, key, period, count)
    values ('visitor', p_visitor, v_day, 1)
    on conflict (scope, key, period) do update
      set count = c.count + 1, updated_at = now()
      where c.count < p_visitor_day_limit
    returning c.count into n;
    if n is null then raise exception 'quota_visitor_daily'; end if;

    -- 4) الحد اليومي لكل IP (يحمي من تدوير مفتاح الزائر).
    n := null;
    insert into public.ai_usage_counters as c (scope, key, period, count)
    values ('ip', p_ip, v_day, 1)
    on conflict (scope, key, period) do update
      set count = c.count + 1, updated_at = now()
      where c.count < p_ip_day_limit
    returning c.count into n;
    if n is null then raise exception 'quota_ip_daily'; end if;
  exception when others then
    if sqlerrm like 'quota\_%' then
      return substr(sqlerrm, 7);   -- الكتلة الداخلية تراجعت بالكامل
    end if;
    raise;
  end;

  -- تنظيف: صفوف اليومي الأقدم من يومين (احتمال صغير لكل طلب).
  if random() < 0.02 then
    delete from public.ai_usage_counters
    where scope in ('visitor', 'ip')
      and period < to_char((now() at time zone 'Asia/Baghdad')::date - 2, 'YYYY-MM-DD');
  end if;

  return 'ok';
end;
$$;

-- يسجّل التوكنز الفعلية للشهر بعد نجاح الاستدعاء (لحد التوكنز الاختياري).
create or replace function public.ai_usage_add_tokens(p_tokens integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month text := to_char((now() at time zone 'Asia/Baghdad')::date, 'YYYY-MM');
begin
  if coalesce(p_tokens, 0) <= 0 or p_tokens > 1000000 then return; end if;
  insert into public.ai_usage_counters as c (scope, key, period, count, tokens)
  values ('month', 'all', v_month, 0, p_tokens)
  on conflict (scope, key, period) do update
    set tokens = c.tokens + p_tokens, updated_at = now();
end;
$$;

-- التنفيذ لـ service_role فقط (الدالة تُستدعى من Edge Function).
revoke all on function public.ai_usage_consume(text, text, integer, integer, integer, bigint)
  from public, anon, authenticated;
revoke all on function public.ai_usage_add_tokens(integer)
  from public, anon, authenticated;
grant execute on function public.ai_usage_consume(text, text, integer, integer, integer, bigint)
  to service_role;
grant execute on function public.ai_usage_add_tokens(integer) to service_role;

notify pgrst, 'reload schema';
