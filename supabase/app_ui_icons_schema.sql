-- أيقونات واجهة الغدير القابلة للتغيير من الإدارة.
-- شعار الغدير الرسمي غير مخزَّن هنا — ثابت في التطبيق.
-- نفّذ في Supabase SQL Editor عند الجاهزية. التطبيق يعمل بدون الجدول (رموز افتراضية + كاش محلي).

create table if not exists public.app_ui_icons (
  slot_id text primary key,
  image_url text not null,
  updated_at timestamptz not null default now(),
  constraint app_ui_icons_slot_id_chk check (
    char_length(trim(slot_id)) > 0
    and slot_id not like 'brand.logo%'
    and slot_id <> 'logo'
  ),
  constraint app_ui_icons_image_url_chk check (char_length(trim(image_url)) > 0)
);

comment on table public.app_ui_icons is
  'Override images for UI icon slots (home/specialty/nav). Ghadeer logo is never stored here.';

alter table public.app_ui_icons enable row level security;

-- قراءة عامة للأيقونات الظاهرة في التطبيق.
drop policy if exists "app_ui_icons_public_read" on public.app_ui_icons;
create policy "app_ui_icons_public_read"
  on public.app_ui_icons
  for select
  to anon, authenticated
  using (true);

-- كتابة لإدارة العيادة فقط. حساب المريض المصدّق لا يغيّر أيقونات التطبيق.
drop policy if exists "app_ui_icons_auth_write" on public.app_ui_icons;
create policy "app_ui_icons_auth_write"
  on public.app_ui_icons
  for all
  to authenticated
  using (public.is_clinic_admin())
  with check (public.is_clinic_admin());

-- رفع صور الأيقونات إلى clinic-media/ui_icons/ من جلسة الإدارة فقط.
drop policy if exists clinic_media_ui_icons_auth_insert on storage.objects;
create policy clinic_media_ui_icons_auth_insert
  on storage.objects for insert to authenticated
  with check (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'ui_icons'
  );

drop policy if exists clinic_media_ui_icons_auth_update on storage.objects;
create policy clinic_media_ui_icons_auth_update
  on storage.objects for update to authenticated
  using (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'ui_icons'
  )
  with check (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'ui_icons'
  );

drop policy if exists clinic_media_ui_icons_auth_delete on storage.objects;
create policy clinic_media_ui_icons_auth_delete
  on storage.objects for delete to authenticated
  using (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'ui_icons'
  );
