-- ============================================================
-- إحصائيات التطبيق والأطباء (مستخدمون + زيارات/تفاعل)
-- نفّذ في Supabase SQL Editor. آمن مع IF NOT EXISTS.
-- ============================================================

-- مستخدمو التطبيق (مفتاح جهاز/زائر فريد)
create table if not exists public.app_users (
  visitor_key text primary key,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  open_count integer not null default 1
);

alter table public.app_users enable row level security;

drop policy if exists "app_users_select_authenticated" on public.app_users;
create policy "app_users_select_authenticated"
  on public.app_users for select to authenticated using (true);

-- تسجيل/تحديث مستخدم التطبيق من العامة (anon + authenticated)
create or replace function public.touch_app_user(p_visitor_key text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_visitor_key is null or length(trim(p_visitor_key)) < 8 then
    return;
  end if;

  insert into public.app_users (visitor_key, first_seen_at, last_seen_at, open_count)
  values (trim(p_visitor_key), now(), now(), 1)
  on conflict (visitor_key) do update
    set last_seen_at = now(),
        open_count = public.app_users.open_count + 1;
end;
$$;

grant select on public.app_users to authenticated;
grant execute on function public.touch_app_user(text) to anon, authenticated;

-- عدّادات تفاعل لكل طبيب (اتصال / واتساب من داخل التطبيق)
alter table public.doctors
  add column if not exists call_taps integer default 0,
  add column if not exists whatsapp_taps integer default 0;

create or replace function public.increment_doctor_call_taps(p_doctor_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.doctors
  set call_taps = coalesce(call_taps, 0) + 1
  where id = p_doctor_id;
end;
$$;

create or replace function public.increment_doctor_whatsapp_taps(p_doctor_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.doctors
  set whatsapp_taps = coalesce(whatsapp_taps, 0) + 1
  where id = p_doctor_id;
end;
$$;

grant execute on function public.increment_doctor_call_taps(uuid) to anon, authenticated;
grant execute on function public.increment_doctor_whatsapp_taps(uuid) to anon, authenticated;

-- ضمان وجود profile_views
alter table public.doctors
  add column if not exists profile_views integer default 0;

create or replace function public.increment_doctor_profile_views(p_doctor_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.doctors
  set profile_views = coalesce(profile_views, 0) + 1
  where id = p_doctor_id;
end;
$$;

grant execute on function public.increment_doctor_profile_views(uuid) to anon, authenticated;
