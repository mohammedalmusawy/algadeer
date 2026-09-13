-- ============================================================
-- تقييمات الأطباء — public.doctor_ratings
-- نفّذ هذا الملف في Supabase SQL Editor.
-- متوافق 100% مع Flutter: lib/doctors/doctor_engagement_service.dart
-- لا يمس doctor_favorites أو أي جدول موجود آخر.
-- ============================================================

create table if not exists public.doctor_ratings (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.doctors(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  comment text not null default '',
  visitor_key text not null,
  created_at timestamptz not null default now(),
  unique (doctor_id, visitor_key)
);

create index if not exists doctor_ratings_doctor_id_idx
  on public.doctor_ratings (doctor_id);

create index if not exists doctor_ratings_visitor_key_idx
  on public.doctor_ratings (visitor_key);

alter table public.doctor_ratings enable row level security;

drop policy if exists "doctor_ratings_public_read" on public.doctor_ratings;
create policy "doctor_ratings_public_read"
  on public.doctor_ratings for select
  to anon, authenticated
  using (true);

drop policy if exists "doctor_ratings_public_insert" on public.doctor_ratings;
create policy "doctor_ratings_public_insert"
  on public.doctor_ratings for insert
  to anon, authenticated
  with check (
    rating between 1 and 5
    and visitor_key <> ''
  );

drop policy if exists "doctor_ratings_public_update" on public.doctor_ratings;
create policy "doctor_ratings_public_update"
  on public.doctor_ratings for update
  to anon, authenticated
  using (true)
  with check (
    rating between 1 and 5
    and visitor_key <> ''
  );

grant select, insert, update on table public.doctor_ratings to anon, authenticated;

notify pgrst, 'reload schema';
