-- ============================================================
-- توثيق تصحيح مطبَّق على المشروع الحي (2026-10-04).
-- للمراجعة فقط. لا يُعاد تنفيذ الملفات المطبَّقة، ولا يُنفَّذ هذا الملف
-- من هذه الجلسة على الإنتاج.
--
-- 1) سياسة الجدول app_ui_icons_auth_write → is_clinic_admin() فقط.
-- 2) سياسة التخزين القديمة بالاسم:
--    "Admin upload doctor images 5uiklb_0"
--    قُصرت على is_clinic_admin()، ثم تُستبدل بالاسم المستقر
--    clinic_media_doctors_auth_insert حتى لا يبقى اسم لوحة التحكم.
-- 3) الطبيب المصرّح له يرفع صورته عبر doctor-card-access
--    (Storage API إلى doctors/{id}/) وليس عبر سياسة authenticated.
-- ============================================================

drop policy if exists "app_ui_icons_auth_write" on public.app_ui_icons;
create policy "app_ui_icons_auth_write"
  on public.app_ui_icons
  for all
  to authenticated
  using (public.is_clinic_admin())
  with check (public.is_clinic_admin());

drop policy if exists "Admin upload doctor images 5uiklb_0" on storage.objects;
drop policy if exists clinic_media_doctors_auth_insert on storage.objects;
create policy clinic_media_doctors_auth_insert
  on storage.objects for insert to authenticated
  with check (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'doctors'
  );

drop policy if exists clinic_media_doctors_auth_update on storage.objects;
create policy clinic_media_doctors_auth_update
  on storage.objects for update to authenticated
  using (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'doctors'
  )
  with check (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'doctors'
  );

drop policy if exists clinic_media_doctors_auth_delete on storage.objects;
create policy clinic_media_doctors_auth_delete
  on storage.objects for delete to authenticated
  using (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'doctors'
  );
