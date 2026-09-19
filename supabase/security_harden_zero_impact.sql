-- ============================================================
-- تشديد أمني بدون تغيير سلوك التطبيق للمستخدم/الأدمن الحالي
-- Idempotent — نفّذه مرة واحدة في Supabase SQL Editor
--
-- الأدمن الوحيد المسموح بالكتابة:
--   almusawyalmusawy90@gmail.com
-- الزائر (anon) والقراءة العامة: بدون تغيير وظيفي.
-- ============================================================

create or replace function public.is_clinic_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    lower(auth.jwt() ->> 'email') = lower('almusawyalmusawy90@gmail.com'),
    false
  );
$$;

revoke all on function public.is_clinic_admin() from public;
grant execute on function public.is_clinic_admin() to anon, authenticated;

-- يطبّق سياسة كتابة أدمن فقط إن وُجد الجدول
create or replace function public._secure_admin_all_policy(
  p_table regclass,
  p_policy text
) returns void
language plpgsql
as $$
begin
  if p_table is null then
    return;
  end if;
  execute format('drop policy if exists %I on %s', p_policy, p_table);
  execute format(
    'create policy %I on %s for all to authenticated using (public.is_clinic_admin()) with check (public.is_clinic_admin())',
    p_policy,
    p_table
  );
end;
$$;

select public._secure_admin_all_policy('public.dynamic_messages'::regclass, 'dynamic_messages_auth_write');
select public._secure_admin_all_policy('public.ad_campaigns'::regclass, 'ad_campaigns_auth_write');
select public._secure_admin_all_policy('public.radiology_centers'::regclass, 'radiology_centers_auth_write');
select public._secure_admin_all_policy('public.labs'::regclass, 'labs_auth_write');
select public._secure_admin_all_policy('public.lab_packages'::regclass, 'lab_packages_auth_write');
select public._secure_admin_all_policy('public.analyses'::regclass, 'analyses_auth_write');
select public._secure_admin_all_policy('public.lab_package_analyses'::regclass, 'lab_package_analyses_auth_write');
select public._secure_admin_all_policy('public.package_templates'::regclass, 'package_templates_auth_write');
select public._secure_admin_all_policy('public.package_template_analyses'::regclass, 'package_template_analyses_auth_write');
select public._secure_admin_all_policy('public.package_images'::regclass, 'package_images_auth_write');
select public._secure_admin_all_policy('public.app_notifications'::regclass, 'app_notifications_auth_write');
select public._secure_admin_all_policy('public.notification_settings'::regclass, 'notification_settings_auth_all');
select public._secure_admin_all_policy('public.doctor_absences'::regclass, 'doctor_absences_auth_write');

-- قراءة المختبرات/التحاليل: نشط للجميع، أو الكل للأدمن فقط
do $$
declare
  r record;
begin
  if to_regclass('public.labs') is not null then
    drop policy if exists "labs_public_read_active" on public.labs;
    create policy "labs_public_read_active"
      on public.labs for select to anon, authenticated
      using (is_active = true or public.is_clinic_admin());
  end if;

  if to_regclass('public.lab_packages') is not null then
    drop policy if exists "lab_packages_public_read_active" on public.lab_packages;
    create policy "lab_packages_public_read_active"
      on public.lab_packages for select to anon, authenticated
      using (is_active = true or public.is_clinic_admin());
  end if;

  if to_regclass('public.analyses') is not null then
    drop policy if exists "analyses_public_read" on public.analyses;
    create policy "analyses_public_read"
      on public.analyses for select to anon, authenticated
      using (is_active = true or public.is_clinic_admin());
  end if;

  if to_regclass('public.app_notifications') is not null then
    drop policy if exists "app_notifications_public_read" on public.app_notifications;
    create policy "app_notifications_public_read"
      on public.app_notifications for select to anon, authenticated
      using (
        public.is_clinic_admin()
        or (
          is_active = true
          and coalesce(status, 'sent') = 'sent'
        )
      );
  end if;

  if to_regclass('public.doctors') is not null then
    alter table public.doctors enable row level security;

    -- أزل أي سياسات قديمة حتى لا تبقى using(true) بجانب السياسة الجديدة
    for r in
      select policyname
      from pg_policies
      where schemaname = 'public' and tablename = 'doctors'
    loop
      execute format('drop policy if exists %I on public.doctors', r.policyname);
    end loop;

    create policy "doctors_public_select"
      on public.doctors for select to anon, authenticated
      using (
        coalesce(is_active, true) = true
        or public.is_clinic_admin()
      );

    create policy "doctors_admin_write"
      on public.doctors for all to authenticated
      using (public.is_clinic_admin())
      with check (public.is_clinic_admin());
  end if;

  if to_regclass('public.app_users') is not null then
    drop policy if exists "app_users_select_authenticated" on public.app_users;
    create policy "app_users_select_authenticated"
      on public.app_users for select to authenticated
      using (public.is_clinic_admin());
  end if;

  if to_regclass('public.app_stat_events') is not null then
    drop policy if exists "app_stat_events_select_authenticated" on public.app_stat_events;
    create policy "app_stat_events_select_authenticated"
      on public.app_stat_events for select to authenticated
      using (public.is_clinic_admin());
  end if;
end $$;

-- Storage: كتابة المجلدات الإدارية للأدمن فقط (إن وُجدت السياسات نعيد إنشاءها)
do $$
declare
  folders text[] := array['dynamic', 'ads', 'labs', 'radiology', 'packages', 'doctors'];
  folder text;
  pol text;
begin
  foreach folder in array folders loop
    pol := format('clinic_media_%s_auth_insert', folder);
    execute format('drop policy if exists %I on storage.objects', pol);
    execute format(
      $f$
      create policy %I on storage.objects for insert to authenticated
      with check (
        public.is_clinic_admin()
        and bucket_id = 'clinic-media'
        and (storage.foldername(name))[1] = %L
      )
      $f$,
      pol,
      folder
    );

    pol := format('clinic_media_%s_auth_update', folder);
    execute format('drop policy if exists %I on storage.objects', pol);
    execute format(
      $f$
      create policy %I on storage.objects for update to authenticated
      using (
        public.is_clinic_admin()
        and bucket_id = 'clinic-media'
        and (storage.foldername(name))[1] = %L
      )
      with check (
        public.is_clinic_admin()
        and bucket_id = 'clinic-media'
        and (storage.foldername(name))[1] = %L
      )
      $f$,
      pol,
      folder,
      folder
    );

    pol := format('clinic_media_%s_auth_delete', folder);
    execute format('drop policy if exists %I on storage.objects', pol);
    execute format(
      $f$
      create policy %I on storage.objects for delete to authenticated
      using (
        public.is_clinic_admin()
        and bucket_id = 'clinic-media'
        and (storage.foldername(name))[1] = %L
      )
      $f$,
      pol,
      folder
    );
  end loop;
end $$;

drop function if exists public._secure_admin_all_policy(regclass, text);

notify pgrst, 'reload schema';
