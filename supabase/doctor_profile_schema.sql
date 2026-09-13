-- ============================================================
-- بطاقة الطبيب الرقمية + التقييمات + الزيارات + الإشعارات
-- نفّذ في Supabase SQL Editor. لا يمس Storage/Auth الأطباء الحالي.
-- ============================================================

-- حقول إضافية على doctors (آمنة مع IF NOT EXISTS عبر DO block)
alter table public.doctors
  add column if not exists years_experience integer default 0,
  add column if not exists patients_served integer default 0,
  add column if not exists profile_views integer default 0,
  add column if not exists languages text default 'العربية',
  add column if not exists qualifications text default '',
  add column if not exists age_group text default 'للكبار والصغار',
  add column if not exists profile_quote text default 'الدقة في التشخيص... خطوة أولى نحو العلاج الصحيح',
  add column if not exists notifications_enabled boolean default true;

-- تقييمات الجمهور
create table if not exists public.doctor_ratings (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.doctors(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  comment text default '',
  visitor_key text not null,
  created_at timestamptz not null default now(),
  unique (doctor_id, visitor_key)
);

create index if not exists doctor_ratings_doctor_id_idx
  on public.doctor_ratings (doctor_id);

-- إشعارات داخل التطبيق (تتحكم بها الإدارة)
create table if not exists public.app_notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null default '',
  type text not null default 'general', -- general | doctor_leave | lab_package | suggestion
  doctor_id uuid references public.doctors(id) on delete set null,
  lab_id uuid,
  package_id uuid,
  is_active boolean not null default true,
  send_push_suggested boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists app_notifications_active_idx
  on public.app_notifications (is_active, created_at desc);

-- RLS
alter table public.doctor_ratings enable row level security;
alter table public.app_notifications enable row level security;

drop policy if exists "doctor_ratings_public_read" on public.doctor_ratings;
create policy "doctor_ratings_public_read"
  on public.doctor_ratings for select
  to anon, authenticated
  using (true);

drop policy if exists "doctor_ratings_public_insert" on public.doctor_ratings;
create policy "doctor_ratings_public_insert"
  on public.doctor_ratings for insert
  to anon, authenticated
  with check (true);

drop policy if exists "doctor_ratings_public_update" on public.doctor_ratings;
create policy "doctor_ratings_public_update"
  on public.doctor_ratings for update
  to anon, authenticated
  using (true)
  with check (true);

drop policy if exists "app_notifications_public_read" on public.app_notifications;
create policy "app_notifications_public_read"
  on public.app_notifications for select
  to anon, authenticated
  using (is_active = true or auth.role() = 'authenticated');

drop policy if exists "app_notifications_auth_write" on public.app_notifications;
create policy "app_notifications_auth_write"
  on public.app_notifications for all
  to authenticated
  using (true)
  with check (true);

-- السماح بزيادة profile_views من العامة (تحديث محدود عبر RPC)
create or replace function public.increment_doctor_profile_views(p_doctor_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  update public.doctors
  set profile_views = coalesce(profile_views, 0) + 1
  where id = p_doctor_id;
end;
$$;

grant execute on function public.increment_doctor_profile_views(uuid) to anon, authenticated;
