-- ============================================================
-- كتالوج الصيدليات المشترك
-- يطبّقه صاحب المشروع في Supabase SQL Editor. لا تشغّله من العميل.
--
-- لا يحذف بيانات الجهاز. التطبيق ينشر النسخة المحلية بزر
-- «نشر النسخة المحفوظة على هذا الجهاز»، وإن لم توجد نسخة محلية
-- ينشر الكتالوج المضمّن في التطبيق.
-- كتابة الزائر ممنوعة. كتابة المالك تمر عبر Edge Function فقط.
-- ============================================================

create table if not exists public.pharmacies (
  id text primary key,
  name text not null,
  is_active boolean not null default true,
  profile jsonb not null default '{}'::jsonb,
  content_revision integer not null default 1,
  updated_at timestamptz not null default now()
);

alter table public.pharmacies enable row level security;

drop policy if exists pharmacies_public_read on public.pharmacies;
create policy pharmacies_public_read
  on public.pharmacies
  for select
  to anon, authenticated
  using (is_active = true or public.is_clinic_admin());

drop policy if exists pharmacies_admin_write on public.pharmacies;
create policy pharmacies_admin_write
  on public.pharmacies
  for all
  to authenticated
  using (public.is_clinic_admin())
  with check (public.is_clinic_admin());

grant select on table public.pharmacies to anon, authenticated;
grant insert, update, delete on table public.pharmacies to authenticated;

-- صور المالك تُرفع بمفتاح service_role داخل pharmacies/{id}/.
-- الإدارة ترفع من الجلسة المصدّقة إلى المجلد نفسه.
drop policy if exists "clinic_media_pharmacies_public_read" on storage.objects;
create policy "clinic_media_pharmacies_public_read"
  on storage.objects for select
  to anon, authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'pharmacies'
  );

drop policy if exists "clinic_media_pharmacies_auth_insert" on storage.objects;
create policy "clinic_media_pharmacies_auth_insert"
  on storage.objects for insert
  to authenticated
  with check (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'pharmacies'
  );

drop policy if exists "clinic_media_pharmacies_auth_update" on storage.objects;
create policy "clinic_media_pharmacies_auth_update"
  on storage.objects for update
  to authenticated
  using (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'pharmacies'
  )
  with check (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'pharmacies'
  );

drop policy if exists "clinic_media_pharmacies_auth_delete" on storage.objects;
create policy "clinic_media_pharmacies_auth_delete"
  on storage.objects for delete
  to authenticated
  using (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'pharmacies'
  );
