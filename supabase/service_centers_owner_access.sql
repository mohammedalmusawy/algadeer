-- ============================================================
-- وصول صاحب مركز العوينات أو التجميل
-- يطبّقه صاحب المشروع في Supabase SQL Editor بعد
-- service_centers_public_schema.sql. لا يُنفَّذ من العميل.
--
-- يوسّع قيد entity_type فقط ليشمل optics و beauty.
-- يحافظ على doctor و lab و pharmacy وبيانات الوصول الموجودة.
-- لا يحذف صفوفًا، ولا يغيّر RLS، ولا يمنح المالك كتابة مباشرة
-- على service_centers. تعديل المالك يبقى عبر Edge Function
-- doctor-card-access بمفتاح service_role بعد نشر الدالة.
-- لا صفوف تجريبية.
-- كامل الملف داخل transaction واحدة.
-- ============================================================

begin;

-- أسماء القيود الحالية تختلف حسب طريقة إنشائها:
-- إنشاء الجدول بـ check مضمّن غالبًا ينتج:
--   entity_owner_access_entity_type_check
--   entity_owner_attempts_entity_type_check
-- لذلك نكتشف الاسم من pg_constraint قبل أي تعديل.

do $$
declare
  r record;
  already_ok boolean := false;
begin
  for r in
    select c.conname,
           pg_get_constraintdef(c.oid) as def
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'entity_owner_access'
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%entity_type%'
  loop
    raise notice 'entity_owner_access check: % -> %', r.conname, r.def;
    if r.def ilike '%optics%'
       and r.def ilike '%beauty%'
       and r.def ilike '%doctor%'
       and r.def ilike '%lab%'
       and r.def ilike '%pharmacy%' then
      already_ok := true;
    else
      execute format(
        'alter table public.entity_owner_access drop constraint %I',
        r.conname
      );
      raise notice 'dropped %', r.conname;
      already_ok := false;
    end if;
  end loop;

  if not already_ok then
    alter table public.entity_owner_access
      add constraint entity_owner_access_entity_type_check
      check (
        entity_type in ('doctor', 'lab', 'pharmacy', 'optics', 'beauty')
      );
    raise notice 'added entity_owner_access_entity_type_check';
  else
    raise notice 'entity_owner_access entity_type check already allows optics/beauty';
  end if;
end $$;

do $$
declare
  r record;
  already_ok boolean := false;
begin
  for r in
    select c.conname,
           pg_get_constraintdef(c.oid) as def
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'entity_owner_attempts'
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%entity_type%'
  loop
    raise notice 'entity_owner_attempts check: % -> %', r.conname, r.def;
    if r.def ilike '%optics%'
       and r.def ilike '%beauty%'
       and r.def ilike '%doctor%'
       and r.def ilike '%lab%'
       and r.def ilike '%pharmacy%' then
      already_ok := true;
    else
      execute format(
        'alter table public.entity_owner_attempts drop constraint %I',
        r.conname
      );
      raise notice 'dropped %', r.conname;
      already_ok := false;
    end if;
  end loop;

  if not already_ok then
    alter table public.entity_owner_attempts
      add constraint entity_owner_attempts_entity_type_check
      check (
        entity_type in ('doctor', 'lab', 'pharmacy', 'optics', 'beauty')
      );
    raise notice 'added entity_owner_attempts_entity_type_check';
  else
    raise notice 'entity_owner_attempts entity_type check already allows optics/beauty';
  end if;
end $$;

commit;

-- تحقق اختياري بعد التنفيذ (لا يعدّل شيئًا):
-- select conname, pg_get_constraintdef(oid)
-- from pg_constraint
-- where conrelid in (
--   'public.entity_owner_access'::regclass,
--   'public.entity_owner_attempts'::regclass
-- )
-- and contype = 'c'
-- and pg_get_constraintdef(oid) ilike '%entity_type%';
