-- ============================================================
-- إحصائيات بفترات: يومي / أسبوعي / شهري / سنوي
-- نفّذ بعد app_stats_schema.sql في Supabase SQL Editor.
-- ============================================================

create table if not exists public.app_stat_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null
    check (event_type in (
      'app_open', 'profile_view', 'call_tap', 'whatsapp_tap', 'rating'
    )),
  doctor_id uuid references public.doctors(id) on delete set null,
  visitor_key text,
  created_at timestamptz not null default now()
);

create index if not exists app_stat_events_created_at_idx
  on public.app_stat_events (created_at desc);

create index if not exists app_stat_events_type_created_idx
  on public.app_stat_events (event_type, created_at desc);

create index if not exists app_stat_events_doctor_created_idx
  on public.app_stat_events (doctor_id, created_at desc)
  where doctor_id is not null;

alter table public.app_stat_events enable row level security;

drop policy if exists "app_stat_events_select_authenticated" on public.app_stat_events;
create policy "app_stat_events_select_authenticated"
  on public.app_stat_events for select to authenticated using (true);

grant select on public.app_stat_events to authenticated;

-- تسجيل حدث (من التطبيق عبر security definer)
create or replace function public.log_app_stat_event(
  p_event_type text,
  p_doctor_id uuid default null,
  p_visitor_key text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_event_type is null or p_event_type not in (
    'app_open', 'profile_view', 'call_tap', 'whatsapp_tap', 'rating'
  ) then
    return;
  end if;

  insert into public.app_stat_events (event_type, doctor_id, visitor_key)
  values (p_event_type, p_doctor_id, nullif(trim(coalesce(p_visitor_key, '')), ''));
end;
$$;

grant execute on function public.log_app_stat_event(text, uuid, text)
  to anon, authenticated;

-- تحديث دوال العدادات لتسجيل الحدث أيضًا
create or replace function public.touch_app_user(p_visitor_key text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_visitor_key is null or length(trim(p_visitor_key)) < 8 then
    return;
  end if;

  insert into public.app_users (visitor_key, first_seen_at, last_seen_at, open_count)
  values (trim(p_visitor_key), now(), now(), 1)
  on conflict (visitor_key) do update
    set last_seen_at = now(),
        open_count = public.app_users.open_count + 1;

  insert into public.app_stat_events (event_type, visitor_key)
  values ('app_open', trim(p_visitor_key));
end;
$$;

create or replace function public.increment_doctor_profile_views(p_doctor_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.doctors
  set profile_views = coalesce(profile_views, 0) + 1
  where id = p_doctor_id;

  insert into public.app_stat_events (event_type, doctor_id)
  values ('profile_view', p_doctor_id);
end;
$$;

create or replace function public.increment_doctor_call_taps(p_doctor_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.doctors
  set call_taps = coalesce(call_taps, 0) + 1
  where id = p_doctor_id;

  insert into public.app_stat_events (event_type, doctor_id)
  values ('call_tap', p_doctor_id);
end;
$$;

create or replace function public.increment_doctor_whatsapp_taps(p_doctor_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.doctors
  set whatsapp_taps = coalesce(whatsapp_taps, 0) + 1
  where id = p_doctor_id;

  insert into public.app_stat_events (event_type, doctor_id)
  values ('whatsapp_tap', p_doctor_id);
end;
$$;

grant execute on function public.touch_app_user(text) to anon, authenticated;
grant execute on function public.increment_doctor_profile_views(uuid) to anon, authenticated;
grant execute on function public.increment_doctor_call_taps(uuid) to anon, authenticated;
grant execute on function public.increment_doctor_whatsapp_taps(uuid) to anon, authenticated;
