-- ============================================================
-- تصحيح ملف المريض بعد تطبيق patient_health_file_schema.sql
-- للمراجعة فقط. لا تُنفَّذ من العميل ولا من هذه الجلسة على الإنتاج.
--
-- 1) حذف الملفات عبر Storage API في Edge Function patient-account،
--    ثم حذف الصفوف وحساب auth والجلسات. حساب الإدارة ممنوع.
-- 2) condition_id في القراءات والأحداث والمرفقات يخص نفس user_id،
--    بما يشمل INSERT وUPDATE والطلب المباشر عبر المفتاح المركّب
--    (condition_id, user_id) وعمود user_id غير القابل للتغيير.
-- ============================================================

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'patient_conditions_id_user_key'
  ) then
    alter table public.patient_conditions
      add constraint patient_conditions_id_user_key unique (id, user_id);
  end if;
end $$;

alter table public.patient_health_attachments
  alter column condition_id set not null;

alter table public.patient_bp_readings
  drop constraint if exists patient_bp_condition_same_user;
alter table public.patient_bp_readings
  add constraint patient_bp_condition_same_user
  foreign key (condition_id, user_id)
  references public.patient_conditions (id, user_id)
  on delete cascade;

alter table public.patient_glucose_readings
  drop constraint if exists patient_glucose_condition_same_user;
alter table public.patient_glucose_readings
  add constraint patient_glucose_condition_same_user
  foreign key (condition_id, user_id)
  references public.patient_conditions (id, user_id)
  on delete cascade;

alter table public.patient_thalassemia_events
  drop constraint if exists patient_thalassemia_condition_same_user;
alter table public.patient_thalassemia_events
  add constraint patient_thalassemia_condition_same_user
  foreign key (condition_id, user_id)
  references public.patient_conditions (id, user_id)
  on delete cascade;

alter table public.patient_health_attachments
  drop constraint if exists patient_attachments_condition_same_user;
alter table public.patient_health_attachments
  add constraint patient_attachments_condition_same_user
  foreign key (condition_id, user_id)
  references public.patient_conditions (id, user_id)
  on delete cascade;

create or replace function public.patient_user_id_immutable()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and new.user_id is distinct from old.user_id then
    raise exception 'user_id_immutable'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists patient_profiles_user_id_immutable on public.patient_health_profiles;
create trigger patient_profiles_user_id_immutable
  before update on public.patient_health_profiles
  for each row execute procedure public.patient_user_id_immutable();

drop trigger if exists patient_conditions_user_id_immutable on public.patient_conditions;
create trigger patient_conditions_user_id_immutable
  before update on public.patient_conditions
  for each row execute procedure public.patient_user_id_immutable();

drop trigger if exists patient_bp_user_id_immutable on public.patient_bp_readings;
create trigger patient_bp_user_id_immutable
  before update on public.patient_bp_readings
  for each row execute procedure public.patient_user_id_immutable();

drop trigger if exists patient_glucose_user_id_immutable on public.patient_glucose_readings;
create trigger patient_glucose_user_id_immutable
  before update on public.patient_glucose_readings
  for each row execute procedure public.patient_user_id_immutable();

drop trigger if exists patient_thalassemia_user_id_immutable on public.patient_thalassemia_events;
create trigger patient_thalassemia_user_id_immutable
  before update on public.patient_thalassemia_events
  for each row execute procedure public.patient_user_id_immutable();

drop trigger if exists patient_attachments_user_id_immutable on public.patient_health_attachments;
create trigger patient_attachments_user_id_immutable
  before update on public.patient_health_attachments
  for each row execute procedure public.patient_user_id_immutable();

-- المسار القديم يحذف storage.objects مباشرة ويترك الملفات على القرص.
-- الدالة ترفض الإدارة وترفض أي استدعاء مباشر؛ الحذف من patient-account فقط.
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
