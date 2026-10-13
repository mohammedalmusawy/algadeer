-- ============================================================
-- التمريض المنزلي (ممرض / ممرضة يزور المريض بالبيت)
-- يطبّقه صاحب المشروع في Supabase SQL Editor مرة وحدة، بعد
-- service_centers_public_schema.sql و service_centers_owner_access.sql.
--
-- يوسّع القيود فقط حتى تقبل 'nursing':
--   service_centers.kind
--   entity_owner_access.entity_type
--   entity_owner_attempts.entity_type
-- لا يحذف صفوفاً، ولا يغيّر RLS، ولا يضيف بيانات تجريبية.
-- كامل الملف داخل transaction واحدة.
-- ============================================================

begin;

do $$
declare
  r record;
begin
  for r in
    select c.conname
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'service_centers'
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%kind%'
  loop
    execute format('alter table public.service_centers drop constraint %I', r.conname);
    raise notice 'dropped %', r.conname;
  end loop;

  alter table public.service_centers
    add constraint service_centers_kind_check
    check (kind in ('optics', 'beauty', 'nursing'));
end $$;

do $$
declare
  tbl text;
  r record;
begin
  foreach tbl in array array['entity_owner_access', 'entity_owner_attempts']
  loop
    for r in
      select c.conname
      from pg_constraint c
      join pg_class t on t.oid = c.conrelid
      join pg_namespace n on n.oid = t.relnamespace
      where n.nspname = 'public'
        and t.relname = tbl
        and c.contype = 'c'
        and pg_get_constraintdef(c.oid) ilike '%entity_type%'
    loop
      execute format('alter table public.%I drop constraint %I', tbl, r.conname);
      raise notice 'dropped %.%', tbl, r.conname;
    end loop;

    execute format(
      'alter table public.%I add constraint %I check (entity_type in '
      '(''doctor'', ''lab'', ''pharmacy'', ''optics'', ''beauty'', ''nursing''))',
      tbl,
      tbl || '_entity_type_check'
    );
  end loop;
end $$;

commit;

-- تحقق اختياري (لا يعدّل شيئاً):
-- select conrelid::regclass, conname, pg_get_constraintdef(oid)
-- from pg_constraint
-- where conname in (
--   'service_centers_kind_check',
--   'entity_owner_access_entity_type_check',
--   'entity_owner_attempts_entity_type_check'
-- );
