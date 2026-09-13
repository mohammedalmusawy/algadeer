-- ============================================================
-- غدير كلينك — مراكز الأشعة (مثل المختبرات)
-- نفّذه في Supabase SQL Editor مرة واحدة (Idempotent).
-- ============================================================

create table if not exists public.radiology_centers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  image_url text,
  address text not null default '',
  phone text not null default '',
  whatsapp text not null default '',
  is_active boolean not null default true,
  is_featured boolean not null default false,
  display_order integer not null default 0,
  map_url text not null default '',
  working_hours text not null default '',
  slogan text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists radiology_centers_active_order_idx
  on public.radiology_centers (is_active, display_order);

alter table public.radiology_centers enable row level security;

drop policy if exists "radiology_centers_public_read" on public.radiology_centers;
create policy "radiology_centers_public_read"
  on public.radiology_centers for select
  to anon, authenticated
  using (is_active = true or auth.role() = 'authenticated');

drop policy if exists "radiology_centers_auth_write" on public.radiology_centers;
create policy "radiology_centers_auth_write"
  on public.radiology_centers for all
  to authenticated
  using (true) with check (true);

-- Storage: radiology/ داخل clinic-media
drop policy if exists "clinic_media_radiology_public_read" on storage.objects;
create policy "clinic_media_radiology_public_read"
  on storage.objects for select
  to anon, authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'radiology'
  );

drop policy if exists "clinic_media_radiology_auth_insert" on storage.objects;
create policy "clinic_media_radiology_auth_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'radiology'
  );

drop policy if exists "clinic_media_radiology_auth_update" on storage.objects;
create policy "clinic_media_radiology_auth_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'radiology'
  )
  with check (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'radiology'
  );

drop policy if exists "clinic_media_radiology_auth_delete" on storage.objects;
create policy "clinic_media_radiology_auth_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'radiology'
  );
