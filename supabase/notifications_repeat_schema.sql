-- تكرار تلقائي للإشعارات — نفّذ إذا شغّلت المخطط السابق قبل إضافة التكرار
alter table public.app_notifications
  add column if not exists repeat_enabled boolean default false,
  add column if not exists repeat_days text[] default '{}',
  add column if not exists repeat_hour int default 9,
  add column if not exists repeat_minute int default 0;

create index if not exists app_notifications_repeat_idx
  on public.app_notifications (repeat_enabled)
  where repeat_enabled = true;
