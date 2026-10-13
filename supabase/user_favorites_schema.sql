-- ============================================================
-- مفضلة المستخدم بحسابه (أطبائي، المختبرات، الأشعة، الصيدليات)
-- يطبّقه صاحب المشروع في Supabase SQL Editor مرة وحدة.
-- كل مستخدم يقرأ ويكتب مفضلته هو فقط. ما يمس أي جدول ثاني.
-- ============================================================

begin;

create table if not exists public.user_favorites (
  user_id uuid not null references auth.users (id) on delete cascade,
  list_key text not null check (
    list_key in (
      'favoriteDoctorIds',
      'favoriteLabIds',
      'favoriteRadiologyIds',
      'favoritePharmacyIds'
    )
  ),
  ids text[] not null default '{}',
  updated_at timestamptz not null default now(),
  primary key (user_id, list_key),
  constraint user_favorites_ids_limit check (cardinality(ids) <= 500)
);

alter table public.user_favorites enable row level security;

drop policy if exists user_favorites_own_select on public.user_favorites;
create policy user_favorites_own_select
  on public.user_favorites for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists user_favorites_own_insert on public.user_favorites;
create policy user_favorites_own_insert
  on public.user_favorites for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists user_favorites_own_update on public.user_favorites;
create policy user_favorites_own_update
  on public.user_favorites for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists user_favorites_own_delete on public.user_favorites;
create policy user_favorites_own_delete
  on public.user_favorites for delete
  to authenticated
  using (user_id = auth.uid());

grant select, insert, update, delete on table public.user_favorites to authenticated;

commit;
