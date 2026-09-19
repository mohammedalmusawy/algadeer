-- ============================================================
-- إحصائيات الباقات (زيارات تفاصيل الباقة)
-- نفّذ بعد lab_stats_schema.sql في Supabase SQL Editor.
-- Idempotent.
-- ============================================================

do $$
begin
  if to_regclass('public.lab_packages') is not null then
    alter table public.lab_packages
      add column if not exists profile_views integer default 0;
  end if;
end $$;

do $$
begin
  if to_regclass('public.app_stat_events') is not null then
    alter table public.app_stat_events
      add column if not exists package_id uuid;

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
        'lab_whatsapp_tap',
        'package_view'
      ));

    create index if not exists app_stat_events_package_created_idx
      on public.app_stat_events (package_id, created_at desc)
      where package_id is not null;
  end if;
end $$;

-- تحديث log_app_stat_event لقبول package_id (متوافق مع الاستدعاءات القديمة)
create or replace function public.log_app_stat_event(
  p_event_type text,
  p_doctor_id uuid default null,
  p_visitor_key text default null,
  p_lab_id uuid default null,
  p_package_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_event_type is null or p_event_type not in (
    'app_open', 'profile_view', 'call_tap', 'whatsapp_tap', 'rating',
    'lab_profile_view', 'lab_call_tap', 'lab_whatsapp_tap', 'package_view'
  ) then
    return;
  end if;

  insert into public.app_stat_events (
    event_type, doctor_id, visitor_key, lab_id, package_id
  )
  values (
    p_event_type,
    p_doctor_id,
    nullif(trim(coalesce(p_visitor_key, '')), ''),
    p_lab_id,
    p_package_id
  );
exception
  when undefined_column then
    insert into public.app_stat_events (event_type, doctor_id, visitor_key, lab_id)
    values (
      p_event_type,
      p_doctor_id,
      nullif(trim(coalesce(p_visitor_key, '')), ''),
      p_lab_id
    );
  when others then
    null;
end;
$$;

grant execute on function public.log_app_stat_event(text, uuid, text, uuid, uuid)
  to anon, authenticated;

create or replace function public.increment_package_profile_views(p_package_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lab_id uuid;
begin
  if p_package_id is null then
    return;
  end if;

  update public.lab_packages
  set profile_views = coalesce(profile_views, 0) + 1
  where id = p_package_id
  returning lab_id into v_lab_id;

  begin
    insert into public.app_stat_events (event_type, lab_id, package_id)
    values ('package_view', v_lab_id, p_package_id);
  exception
    when undefined_column then
      insert into public.app_stat_events (event_type, lab_id)
      values ('package_view', v_lab_id);
    when others then
      null;
  end;
exception
  when undefined_column then
    -- العمود غير موجود بعد — لا نفشل التطبيق
    null;
  when others then
    null;
end;
$$;

grant execute on function public.increment_package_profile_views(uuid)
  to anon, authenticated;
