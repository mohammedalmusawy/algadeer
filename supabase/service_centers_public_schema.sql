-- ============================================================
-- مراكز العوينات وفحص البصر، ومراكز التجميل
-- يطبّقه صاحب المشروع في Supabase SQL Editor. لا تشغّله من العميل.
--
-- الجدول يبدأ فارغاً. لا صفوف تجريبية.
-- الزائر يقرأ المراكز الظاهرة فقط. الكتابة للإدارة عبر is_clinic_admin().
-- إخفاء زر الإدارة في التطبيق ليس حماية؛ السياسة هنا هي الحماية.
-- لا يحذف جداول الصيدليات أو المستلزمات أو العلاج الطبيعي.
-- يعتمد على public.is_clinic_admin() الموجودة مسبقاً.
-- ============================================================

create table if not exists public.service_centers (
  id text primary key,
  kind text not null check (kind in ('optics', 'beauty')),
  name text not null,
  is_active boolean not null default true,
  display_order integer not null default 0,
  profile jsonb not null default '{}'::jsonb,
  content_revision integer not null default 1,
  updated_at timestamptz not null default now()
);

create index if not exists service_centers_kind_order_idx
  on public.service_centers (kind, display_order, name);

alter table public.service_centers enable row level security;

drop policy if exists service_centers_public_read on public.service_centers;
create policy service_centers_public_read
  on public.service_centers
  for select
  to anon, authenticated
  using (is_active = true or public.is_clinic_admin());

drop policy if exists service_centers_admin_write on public.service_centers;
create policy service_centers_admin_write
  on public.service_centers
  for all
  to authenticated
  using (public.is_clinic_admin())
  with check (public.is_clinic_admin());

grant select on table public.service_centers to anon, authenticated;
grant insert, update, delete on table public.service_centers to authenticated;

-- صور الإدارة تُرفع من الجلسة المصدّقة إلى service-centers/{id}/.
drop policy if exists "clinic_media_service_centers_public_read" on storage.objects;
create policy "clinic_media_service_centers_public_read"
  on storage.objects for select
  to anon, authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'service-centers'
  );

drop policy if exists "clinic_media_service_centers_auth_insert" on storage.objects;
create policy "clinic_media_service_centers_auth_insert"
  on storage.objects for insert
  to authenticated
  with check (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'service-centers'
  );

drop policy if exists "clinic_media_service_centers_auth_update" on storage.objects;
create policy "clinic_media_service_centers_auth_update"
  on storage.objects for update
  to authenticated
  using (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'service-centers'
  )
  with check (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'service-centers'
  );

drop policy if exists "clinic_media_service_centers_auth_delete" on storage.objects;
create policy "clinic_media_service_centers_auth_delete"
  on storage.objects for delete
  to authenticated
  using (
    public.is_clinic_admin()
    and bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'service-centers'
  );
