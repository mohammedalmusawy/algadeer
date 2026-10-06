-- ============================================================
-- ملف المريض الصحي وبطاقة المتابعة
-- يطبّقه صاحب المشروع في Supabase SQL Editor. لا تشغّله من العميل
-- ولا على أمل أنه طُبّق: التطبيق يُظهر خطأ إن غابت الجداول.
--
-- قبل تفعيل تسجيل المرضى: نفّذ supabase/security_harden_zero_impact.sql
-- إن لم يكن مطبّقاً. بدونه أي مستخدم authenticated قد يكتب جداول
-- المختبرات القديمة. الملف الصحي لا يمنح الإدارة صلاحية عليه.
--
-- البريد: فعّل تأكيد الإيميل وSMTP وRedirect URLs من لوحة Authentication.
-- التطبيق يطلب الإرسال ولا يتحقق من وصول الرسالة.
-- ============================================================

create table if not exists public.patient_health_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  consent_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.patient_conditions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('hypertension', 'diabetes', 'thalassemia', 'other')),
  label text not null default '',
  thalassemia_type text not null default '',
  prescribed_treatment text not null default '',
  reviews_note text not null default '',
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.patient_bp_readings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  condition_id uuid not null references public.patient_conditions (id) on delete cascade,
  systolic integer not null,
  diastolic integer not null,
  pulse integer,
  measured_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.patient_glucose_readings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  condition_id uuid not null references public.patient_conditions (id) on delete cascade,
  value numeric not null,
  unit text not null check (unit in ('mg/dL', 'mmol/L')),
  timing text not null check (timing in ('fasting', 'after_meal', 'random')),
  measured_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.patient_thalassemia_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  condition_id uuid not null references public.patient_conditions (id) on delete cascade,
  event_kind text not null check (event_kind in ('appointment', 'transfusion', 'lab_result')),
  title text not null,
  details text not null default '',
  occurred_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.patient_health_attachments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  condition_id uuid references public.patient_conditions (id) on delete cascade,
  storage_path text not null,
  file_name text not null,
  created_at timestamptz not null default now()
);

create index if not exists patient_conditions_user_idx
  on public.patient_conditions (user_id);
create index if not exists patient_bp_user_idx
  on public.patient_bp_readings (user_id, measured_at desc);
create index if not exists patient_glucose_user_idx
  on public.patient_glucose_readings (user_id, measured_at desc);
create index if not exists patient_thal_user_idx
  on public.patient_thalassemia_events (user_id, occurred_at desc);
create index if not exists patient_attach_user_idx
  on public.patient_health_attachments (user_id);

alter table public.patient_health_profiles enable row level security;
alter table public.patient_conditions enable row level security;
alter table public.patient_bp_readings enable row level security;
alter table public.patient_glucose_readings enable row level security;
alter table public.patient_thalassemia_events enable row level security;
alter table public.patient_health_attachments enable row level security;

alter table public.patient_health_profiles force row level security;
alter table public.patient_conditions force row level security;
alter table public.patient_bp_readings force row level security;
alter table public.patient_glucose_readings force row level security;
alter table public.patient_thalassemia_events force row level security;
alter table public.patient_health_attachments force row level security;

revoke all on table public.patient_health_profiles from anon, public;
revoke all on table public.patient_conditions from anon, public;
revoke all on table public.patient_bp_readings from anon, public;
revoke all on table public.patient_glucose_readings from anon, public;
revoke all on table public.patient_thalassemia_events from anon, public;
revoke all on table public.patient_health_attachments from anon, public;

grant select, insert, update, delete on table public.patient_health_profiles to authenticated;
grant select, insert, update, delete on table public.patient_conditions to authenticated;
grant select, insert, update, delete on table public.patient_bp_readings to authenticated;
grant select, insert, update, delete on table public.patient_glucose_readings to authenticated;
grant select, insert, update, delete on table public.patient_thalassemia_events to authenticated;
grant select, insert, update, delete on table public.patient_health_attachments to authenticated;

drop policy if exists patient_health_profiles_owner on public.patient_health_profiles;
create policy patient_health_profiles_owner
  on public.patient_health_profiles
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists patient_conditions_owner on public.patient_conditions;
create policy patient_conditions_owner
  on public.patient_conditions
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists patient_bp_owner on public.patient_bp_readings;
create policy patient_bp_owner
  on public.patient_bp_readings
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists patient_glucose_owner on public.patient_glucose_readings;
create policy patient_glucose_owner
  on public.patient_glucose_readings
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists patient_thalassemia_owner on public.patient_thalassemia_events;
create policy patient_thalassemia_owner
  on public.patient_thalassemia_events
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists patient_attachments_owner on public.patient_health_attachments;
create policy patient_attachments_owner
  on public.patient_health_attachments
  for all to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

insert into storage.buckets (id, name, public)
values ('patient-health', 'patient-health', false)
on conflict (id) do update set public = false;

drop policy if exists patient_health_storage_select on storage.objects;
create policy patient_health_storage_select
  on storage.objects for select to authenticated
  using (
    bucket_id = 'patient-health'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists patient_health_storage_insert on storage.objects;
create policy patient_health_storage_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'patient-health'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists patient_health_storage_update on storage.objects;
create policy patient_health_storage_update
  on storage.objects for update to authenticated
  using (
    bucket_id = 'patient-health'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'patient-health'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists patient_health_storage_delete on storage.objects;
create policy patient_health_storage_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'patient-health'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- حذف الحساب لا يمس storage.objects مباشرة. الملفات تُحذف عبر Storage API
-- في Edge Function patient-account، ثم تُحذف الصفوف والحساب والجلسات.
-- إن أُعيد تشغيل هذا الملف بعد التطبيق الأول، الدالة ترفض المسار القديم.
create or replace function public.delete_own_patient_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_clinic_admin() then
    raise exception 'admin_forbidden'
      using errcode = '42501';
  end if;
  raise exception 'use_storage_api'
    using errcode = 'P0001',
          hint = 'patient-account edge function';
end;
$$;

revoke all on function public.delete_own_patient_account() from public, anon, authenticated;
grant execute on function public.delete_own_patient_account() to authenticated;
