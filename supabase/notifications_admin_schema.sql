-- ============================================================
-- إدارة إشعارات الغدير (مستقل — يعمل حتى لو لم يُنشأ الجدول سابقًا)
-- آمن: لا يحذف بيانات، ولا يفعّل Push خارجي.
-- نفّذ مرة واحدة في Supabase SQL Editor.
-- ============================================================

-- 1) جدول الإشعارات (إنشاء كامل إن لم يوجد)
create table if not exists public.app_notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null default '',
  type text not null default 'general',
  doctor_id uuid,
  lab_id uuid,
  package_id uuid,
  is_active boolean not null default true,
  send_push_suggested boolean not null default false,
  created_at timestamptz not null default now()
);

-- ربط اختياري بـ doctors إن وُجد الجدول
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'doctors'
  ) then
    begin
      alter table public.app_notifications
        drop constraint if exists app_notifications_doctor_id_fkey;
      alter table public.app_notifications
        add constraint app_notifications_doctor_id_fkey
        foreign key (doctor_id) references public.doctors(id) on delete set null;
    exception when others then
      -- إن وُجد قيد بنفس المعنى أو تعارض بسيط نتجاهل
      null;
    end;

    alter table public.doctors
      add column if not exists notifications_enabled boolean default true;
  end if;
end $$;

-- 2) أعمدة الإدارة (آمنة إن كان الجدول قديمًا أو جديدًا)
alter table public.app_notifications
  add column if not exists status text default 'sent',
  add column if not exists origin text default 'manual',
  add column if not exists source text default 'ghadeer',
  add column if not exists audience text default 'all',
  add column if not exists destination_kind text default 'home',
  add column if not exists destination_id uuid,
  add column if not exists scheduled_at timestamptz,
  add column if not exists sent_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists idempotency_key text,
  add column if not exists template_key text,
  add column if not exists meta jsonb default '{}'::jsonb,
  add column if not exists updated_at timestamptz default now();

update public.app_notifications
set status = 'sent'
where status is null or status = '';

create index if not exists app_notifications_active_idx
  on public.app_notifications (is_active, created_at desc);

create unique index if not exists app_notifications_idempotency_uidx
  on public.app_notifications (idempotency_key)
  where idempotency_key is not null;

create index if not exists app_notifications_status_idx
  on public.app_notifications (status, scheduled_at desc nulls last, created_at desc);

-- 3) صلاحيات المختبر/العرض — فقط إن وُجدت الجداول
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'labs'
  ) then
    alter table public.labs
      add column if not exists notifications_enabled boolean default false;
  end if;

  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'lab_packages'
  ) then
    alter table public.lab_packages
      add column if not exists notify_enabled boolean default false;
  end if;
end $$;

-- 4) إعدادات التوقيت
create table if not exists public.notification_settings (
  id text primary key default 'default',
  timezone text not null default 'Asia/Baghdad',
  doctor_tomorrow_hour int not null default 21,
  doctor_tomorrow_minute int not null default 0,
  doctor_today_hour int not null default 8,
  doctor_today_minute int not null default 0,
  lab_expiry_hours_before int not null default 24,
  quiet_hours_enabled boolean not null default false,
  quiet_start_hour int not null default 0,
  quiet_end_hour int not null default 6,
  updated_at timestamptz not null default now()
);

insert into public.notification_settings (id)
values ('default')
on conflict (id) do nothing;

-- 5) RLS
alter table public.app_notifications enable row level security;
alter table public.notification_settings enable row level security;

drop policy if exists "app_notifications_public_read" on public.app_notifications;
create policy "app_notifications_public_read"
  on public.app_notifications for select
  to anon, authenticated
  using (
    auth.role() = 'authenticated'
    or (
      is_active = true
      and coalesce(status, 'sent') = 'sent'
    )
  );

drop policy if exists "app_notifications_auth_write" on public.app_notifications;
create policy "app_notifications_auth_write"
  on public.app_notifications for all
  to authenticated
  using (true)
  with check (true);

drop policy if exists "notification_settings_auth_all" on public.notification_settings;
create policy "notification_settings_auth_all"
  on public.notification_settings for all
  to authenticated
  using (true)
  with check (true);

drop policy if exists "notification_settings_public_read" on public.notification_settings;
create policy "notification_settings_public_read"
  on public.notification_settings for select
  to anon, authenticated
  using (true);

-- 6) تكرار تلقائي (طبيب / مختبر / عيادة الغدير)
alter table public.app_notifications
  add column if not exists repeat_enabled boolean default false,
  add column if not exists repeat_days text[] default '{}',
  add column if not exists repeat_hour int default 9,
  add column if not exists repeat_minute int default 0;

create index if not exists app_notifications_repeat_idx
  on public.app_notifications (repeat_enabled)
  where repeat_enabled = true;
