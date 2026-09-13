-- ============================================================
-- غدير كلينك — حملات إعلانية (تحكم كامل من الإدارة)
-- نفّذه مرة واحدة في Supabase SQL Editor.
-- إن لم يُنفَّذ: التطبيق يعمل طبيعيًا بدون إعلانات.
-- ============================================================

create table if not exists public.ad_campaigns (
  id uuid primary key default gen_random_uuid(),
  title text not null default '',
  body text not null default '',
  media_type text not null default 'image'
    check (media_type in ('image', 'video')),
  image_url text not null default '',
  video_url text not null default '',
  click_url text not null default '',
  placement text not null default 'home',
  is_active boolean not null default false,
  starts_at timestamptz,
  ends_at timestamptz,
  -- 0 = بدون إخفاء تلقائي بالثواني (يبقى حتى الإغلاق أو حد الظهور)
  display_seconds integer not null default 0,
  -- null أو 0 = بلا حد إجمالي
  max_total_impressions integer,
  -- كم مرة كحد أقصى لنفس الجهاز/المستخدم
  max_per_user integer not null default 3,
  -- حد يومي لنفس المستخدم (0 = بلا حد يومي إضافي)
  max_per_user_per_day integer not null default 1,
  impression_count integer not null default 0,
  click_count integer not null default 0,
  priority integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ad_campaigns_active_placement_idx
  on public.ad_campaigns (placement, is_active, priority desc);

create or replace function public.set_ad_campaigns_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_ad_campaigns_updated_at on public.ad_campaigns;
create trigger trg_ad_campaigns_updated_at
  before update on public.ad_campaigns
  for each row
  execute function public.set_ad_campaigns_updated_at();

alter table public.ad_campaigns enable row level security;

-- قراءة عامة: حملات مفعّلة ضمن الفترة فقط
drop policy if exists "ad_campaigns_public_read" on public.ad_campaigns;
create policy "ad_campaigns_public_read"
  on public.ad_campaigns for select
  to anon, authenticated
  using (
    is_active = true
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at >= now())
  );

-- إدارة كاملة للمسجّلين
drop policy if exists "ad_campaigns_auth_write" on public.ad_campaigns;
create policy "ad_campaigns_auth_write"
  on public.ad_campaigns for all
  to authenticated
  using (true)
  with check (true);

-- زيادة عدّاد الظهور (آمن للاستدعاء من العميل)
create or replace function public.increment_ad_impression(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.ad_campaigns
  set impression_count = impression_count + 1
  where id = p_id
    and is_active = true;
end;
$$;

create or replace function public.increment_ad_click(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.ad_campaigns
  set click_count = click_count + 1
  where id = p_id
    and is_active = true;
end;
$$;

grant execute on function public.increment_ad_impression(uuid) to anon, authenticated;
grant execute on function public.increment_ad_click(uuid) to anon, authenticated;

-- Storage: مجلد ads/ داخل clinic-media لصور الحملات
drop policy if exists "clinic_media_ads_public_read" on storage.objects;
create policy "clinic_media_ads_public_read"
  on storage.objects for select
  to anon, authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'ads'
  );

drop policy if exists "clinic_media_ads_auth_insert" on storage.objects;
create policy "clinic_media_ads_auth_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'ads'
  );

drop policy if exists "clinic_media_ads_auth_update" on storage.objects;
create policy "clinic_media_ads_auth_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'ads'
  )
  with check (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'ads'
  );

drop policy if exists "clinic_media_ads_auth_delete" on storage.objects;
create policy "clinic_media_ads_auth_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'ads'
  );
