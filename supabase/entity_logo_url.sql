-- ============================================================
-- شعار اختياري مشترك
-- للمراجعة في Supabase SQL Editor. لا يُنفَّذ من هذه المهمة.
--
-- 1) عمود logo_url للأطباء والمختبرات والأشعة (فارغ افتراضيًا).
-- 2) جدول entity_logos لشعار العلاج الطبيعي والمستلزمات بينما
--    يبقى محتوى كتالوجهما على الجهاز.
-- 3) سياسات تخزين لمجلدَي physio/ و supplies/ (قراءة عامة،
--    كتابة is_clinic_admin) حتى يعمل المسار الموحّد
--    {folder}/{entityId}/logos/...
--
-- لا يغيّر image_url ولا صفوفًا موجودة.
-- الصيدليات ومراكز العوينات/التجميل تحفظ الشعار في profile.
-- نفّذ هذا الملف قبل نشر دالة doctor-card-access التي تكتب logo_url.
-- ============================================================

begin;

alter table public.doctors
  add column if not exists logo_url text;

alter table public.labs
  add column if not exists logo_url text;

alter table public.radiology_centers
  add column if not exists logo_url text;

create table if not exists public.entity_logos (
  entity_type text not null check (entity_type in ('physio', 'supplies')),
  entity_id text not null,
  logo_url text not null default '',
  updated_at timestamptz not null default now(),
  primary key (entity_type, entity_id)
);

alter table public.entity_logos enable row level security;

drop policy if exists entity_logos_public_read on public.entity_logos;
create policy entity_logos_public_read
  on public.entity_logos
  for select
  to anon, authenticated
  using (true);

drop policy if exists entity_logos_admin_write on public.entity_logos;
create policy entity_logos_admin_write
  on public.entity_logos
  for all
  to authenticated
  using (public.is_clinic_admin())
  with check (public.is_clinic_admin());

grant select on table public.entity_logos to anon, authenticated;
grant insert, update, delete on table public.entity_logos to authenticated;

-- تخزين: المسار الموحّد physio/{id}/logos و supplies/{id}/logos
-- يعتمد على الحاوية clinic-media و is_clinic_admin() الموجودين.
drop policy if exists "clinic_media_physio_public_read" on storage.objects;
create policy "clinic_media_physio_public_read"
  on storage.objects for select
  to anon, authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'physio'
  );

drop policy if exists "clinic_media_physio_auth_insert" on storage.objects;
create policy "clinic_media_physio_auth_insert"
  on storage.objects for insert
  to authenticated
  with check (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'physio'
  );

drop policy if exists "clinic_media_physio_auth_update" on storage.objects;
create policy "clinic_media_physio_auth_update"
  on storage.objects for update
  to authenticated
  using (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'physio'
  )
  with check (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'physio'
  );

drop policy if exists "clinic_media_physio_auth_delete" on storage.objects;
create policy "clinic_media_physio_auth_delete"
  on storage.objects for delete
  to authenticated
  using (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'physio'
  );

drop policy if exists "clinic_media_supplies_public_read" on storage.objects;
create policy "clinic_media_supplies_public_read"
  on storage.objects for select
  to anon, authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'supplies'
  );

drop policy if exists "clinic_media_supplies_auth_insert" on storage.objects;
create policy "clinic_media_supplies_auth_insert"
  on storage.objects for insert
  to authenticated
  with check (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'supplies'
  );

drop policy if exists "clinic_media_supplies_auth_update" on storage.objects;
create policy "clinic_media_supplies_auth_update"
  on storage.objects for update
  to authenticated
  using (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'supplies'
  )
  with check (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'supplies'
  );

drop policy if exists "clinic_media_supplies_auth_delete" on storage.objects;
create policy "clinic_media_supplies_auth_delete"
  on storage.objects for delete
  to authenticated
  using (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'supplies'
  );

commit;
