-- ============================================================
-- العبارات الديناميكية — جدول كامل + RLS
-- Idempotent
-- ============================================================

create table if not exists public.dynamic_messages (
  id uuid primary key default gen_random_uuid(),
  placement text not null default 'home',
  title text not null default 'رسالة اليوم',
  body text not null,
  priority integer not null default 0,
  is_active boolean not null default true,
  -- تلميح سياقي اختياري لمستقبل AI (لا يُعرض للمستخدم إن فُرّغ)
  context_hint text not null default '',
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.dynamic_messages
  add column if not exists context_hint text not null default '';

alter table public.dynamic_messages
  add column if not exists updated_at timestamptz not null default now();

create index if not exists dynamic_messages_placement_active_idx
  on public.dynamic_messages (placement, is_active, priority desc);

create or replace function public.set_dynamic_messages_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_dynamic_messages_updated_at on public.dynamic_messages;
create trigger trg_dynamic_messages_updated_at
  before update on public.dynamic_messages
  for each row
  execute function public.set_dynamic_messages_updated_at();

alter table public.dynamic_messages enable row level security;

-- قراءة عامة: العبارات المفعّلة ضمن الفترة الزمنية فقط
drop policy if exists "dynamic_messages_public_read" on public.dynamic_messages;
create policy "dynamic_messages_public_read"
  on public.dynamic_messages for select
  to anon, authenticated
  using (
    is_active = true
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at >= now())
  );

-- إدارة كاملة للمسجّلين (لوحة الإدارة)
drop policy if exists "dynamic_messages_auth_write" on public.dynamic_messages;
create policy "dynamic_messages_auth_write"
  on public.dynamic_messages for all
  to authenticated
  using (true)
  with check (true);

-- بذرة أولية مرة واحدة إن كان الجدول فارغًا
insert into public.dynamic_messages (placement, title, body, priority, is_active)
select 'home', 'رسالة اليوم',
  'لا تؤجل استشارة الطبيب عند استمرار الأعراض أو تكرارها.',
  10, true
where not exists (select 1 from public.dynamic_messages limit 1);
