-- ============================================================
-- إحصائيات المختبرات (زيارات / اتصال / واتساب)
-- نفّذ بعد app_stats_schema.sql و app_stats_periods_schema.sql
-- ============================================================

-- عدّادات على جدول المختبرات
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'labs'
  ) then
    alter table public.labs
      add column if not exists profile_views integer default 0,
      add column if not exists call_taps integer default 0,
      add column if not exists whatsapp_taps integer default 0;
  end if;
end $$;

-- عمود المختبر في سجل الأحداث (إن وُجد الجدول)
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'app_stat_events'
  ) then
    alter table public.app_stat_events
      add column if not exists lab_id uuid;

    -- توسيع أنواع الأحداث لتشمل المختبرات
    alter table public.app_stat_events
      drop constraint if exists app_stat_events_event_type_check;

    alter table public.app_stat_events
      add constraint app_stat_events_event_type_check
      check (event_type in (
        'app_open',
        'profile_view',
        'call_tap',
        'whatsapp_tap',
        'rating',
        'lab_profile_view',
        'lab_call_tap',
        'lab_whatsapp_tap'
      ));

    create index if not exists app_stat_events_lab_created_idx
      on public.app_stat_events (lab_id, created_at desc)
      where lab_id is not null;
  end if;
end $$;

-- دالة تسجيل حدث محدّثة (مع lab_id)
create or replace function public.log_app_stat_event(
  p_event_type text,
  p_doctor_id uuid default null,
  p_visitor_key text default null,
  p_lab_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_event_type is null or p_event_type not in (
    'app_open', 'profile_view', 'call_tap', 'whatsapp_tap', 'rating',
    'lab_profile_view', 'lab_call_tap', 'lab_whatsapp_tap'
  ) then
    return;
  end if;

  insert into public.app_stat_events (event_type, doctor_id, visitor_key, lab_id)
  values (
    p_event_type,
    p_doctor_id,
    nullif(trim(coalesce(p_visitor_key, '')), ''),
    p_lab_id
  );
end;
$$;

grant execute on function public.log_app_stat_event(text, uuid, text, uuid)
  to anon, authenticated;

-- زيارة ملف مختبر
create or replace function public.increment_lab_profile_views(p_lab_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.labs
  set profile_views = coalesce(profile_views, 0) + 1
  where id = p_lab_id;

  insert into public.app_stat_events (event_type, lab_id)
  values ('lab_profile_view', p_lab_id);
exception
  when undefined_table then
    null;
  when undefined_column then
    begin
      update public.labs
      set profile_views = coalesce(profile_views, 0) + 1
      where id = p_lab_id;
    exception when others then null;
    end;
end;
$$;

create or replace function public.increment_lab_call_taps(p_lab_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.labs
  set call_taps = coalesce(call_taps, 0) + 1
  where id = p_lab_id;

  insert into public.app_stat_events (event_type, lab_id)
  values ('lab_call_tap', p_lab_id);
exception
  when undefined_table then
    null;
  when undefined_column then
    begin
      update public.labs
      set call_taps = coalesce(call_taps, 0) + 1
      where id = p_lab_id;
    exception when others then null;
    end;
end;
$$;

create or replace function public.increment_lab_whatsapp_taps(p_lab_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.labs
  set whatsapp_taps = coalesce(whatsapp_taps, 0) + 1
  where id = p_lab_id;

  insert into public.app_stat_events (event_type, lab_id)
  values ('lab_whatsapp_tap', p_lab_id);
exception
  when undefined_table then
    null;
  when undefined_column then
    begin
      update public.labs
      set whatsapp_taps = coalesce(whatsapp_taps, 0) + 1
      where id = p_lab_id;
    exception when others then null;
    end;
end;
$$;

grant execute on function public.increment_lab_profile_views(uuid) to anon, authenticated;
grant execute on function public.increment_lab_call_taps(uuid) to anon, authenticated;
grant execute on function public.increment_lab_whatsapp_taps(uuid) to anon, authenticated;
