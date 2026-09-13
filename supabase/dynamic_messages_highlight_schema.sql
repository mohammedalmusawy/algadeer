-- ============================================================
-- العبارة الديناميكية — بطاقة هوية خفيفة (صورة + شارة)
-- Idempotent — نفّذه مرة واحدة بعد dynamic_messages_schema.sql
-- ============================================================

alter table public.dynamic_messages
  add column if not exists image_url text not null default '';

alter table public.dynamic_messages
  add column if not exists badge text not null default '';

alter table public.dynamic_messages
  add column if not exists link_url text not null default '';

-- وجهة اختيارية بعد فتح التفاصيل (طبيب / مختبر / أشعة / رابط)
alter table public.dynamic_messages
  add column if not exists destination_kind text not null default 'none';

alter table public.dynamic_messages
  add column if not exists destination_id text not null default '';

-- عنوان مكتوب + رابط خرائط (مثل المختبرات/الأشعة)
alter table public.dynamic_messages
  add column if not exists address text not null default '';

alter table public.dynamic_messages
  add column if not exists map_url text not null default '';

-- تأكد أن bucket الصور عام للقراءة (مطلوب لـ getPublicUrl)
insert into storage.buckets (id, name, public)
values ('clinic-media', 'clinic-media', true)
on conflict (id) do update set public = true;

-- Storage: مجلد dynamic/ لصور العبارات
drop policy if exists "clinic_media_dynamic_public_read" on storage.objects;
create policy "clinic_media_dynamic_public_read"
  on storage.objects for select
  to anon, authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'dynamic'
  );

drop policy if exists "clinic_media_dynamic_auth_insert" on storage.objects;
create policy "clinic_media_dynamic_auth_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'dynamic'
  );

drop policy if exists "clinic_media_dynamic_auth_update" on storage.objects;
create policy "clinic_media_dynamic_auth_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'dynamic'
  )
  with check (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'dynamic'
  );

drop policy if exists "clinic_media_dynamic_auth_delete" on storage.objects;
create policy "clinic_media_dynamic_auth_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'dynamic'
  );
