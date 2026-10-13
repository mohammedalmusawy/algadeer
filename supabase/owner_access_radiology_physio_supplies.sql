-- ============================================================
-- دخول المالك للأشعة والعلاج الطبيعي والتجهيزات + الدليل المشترك
-- يطبّقه صاحب المشروع في Supabase SQL Editor مرة وحدة.
--
-- 1) جدولا physio_centers و supply_vendors (مثل pharmacies): قبلها كانت
--    بيانات العلاج الطبيعي والتجهيزات محفوظة على جهاز الإدارة فقط.
-- 2) توسيع قيد entity_type ليقبل radiology و physio و supply.
-- 3) قراءة عامة لصور physio/ و supplies/ بـ clinic-media.
-- لا يحذف صفوفاً ولا بيانات. كتابة الزائر ممنوعة؛ المالك عبر Edge Function فقط.
-- ============================================================

begin;

create table if not exists public.physio_centers (
  id text primary key,
  name text not null,
  is_active boolean not null default true,
  profile jsonb not null default '{}'::jsonb,
  content_revision integer not null default 1,
  updated_at timestamptz not null default now()
);

create table if not exists public.supply_vendors (
  id text primary key,
  name text not null,
  is_active boolean not null default true,
  profile jsonb not null default '{}'::jsonb,
  content_revision integer not null default 1,
  updated_at timestamptz not null default now()
);

do $$
declare
  t text;
begin
  foreach t in array array['physio_centers', 'supply_vendors'] loop
    execute format('alter table public.%I enable row level security', t);

    execute format('drop policy if exists %I on public.%I', t || '_public_read', t);
    execute format(
      -- الكل يقرأ حتى المخفي: التطبيق فيه كتالوج مدمج، فلازم يعرف إن
      -- البطاقة انخفت حتى ما تبقى ظاهرة من الكتالوج.
      'create policy %I on public.%I for select to anon, authenticated '
      'using (true)',
      t || '_public_read', t
    );

    execute format('drop policy if exists %I on public.%I', t || '_admin_write', t);
    execute format(
      'create policy %I on public.%I for all to authenticated '
      'using (public.is_clinic_admin()) with check (public.is_clinic_admin())',
      t || '_admin_write', t
    );

    execute format('grant select on table public.%I to anon, authenticated', t);
    execute format('grant insert, update, delete on table public.%I to authenticated', t);
  end loop;
end $$;

-- صور المالك تُرفع بمفتاح service_role. الإدارة ترفع من جلستها.
do $$
declare
  f text;
begin
  foreach f in array array['physio', 'supplies'] loop
    execute format('drop policy if exists %I on storage.objects', 'clinic_media_' || f || '_public_read');
    execute format(
      'create policy %I on storage.objects for select to anon, authenticated '
      'using (bucket_id = ''clinic-media'' and (storage.foldername(name))[1] = %L)',
      'clinic_media_' || f || '_public_read', f
    );
    execute format('drop policy if exists %I on storage.objects', 'clinic_media_' || f || '_admin_insert');
    execute format(
      'create policy %I on storage.objects for insert to authenticated '
      'with check (public.is_clinic_admin() and bucket_id = ''clinic-media'' '
      'and (storage.foldername(name))[1] = %L)',
      'clinic_media_' || f || '_admin_insert', f
    );
  end loop;
end $$;

-- قيد الأنواع: نضيف radiology و physio و supply ونحافظ على الباقي.
do $$
declare
  tbl text;
  r record;
begin
  foreach tbl in array array['entity_owner_access', 'entity_owner_attempts'] loop
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
    end loop;

    execute format(
      'alter table public.%I add constraint %I check (entity_type in '
      '(''doctor'', ''lab'', ''pharmacy'', ''optics'', ''beauty'', ''nursing'', '
      '''radiology'', ''physio'', ''supply''))',
      tbl,
      tbl || '_entity_type_check'
    );
  end loop;
end $$;

commit;

-- بعد التطبيق: من الإدارة افتح «العلاج الطبيعي» و«التجهيزات» واضغط
-- «نشر للدليل المشترك» مرة وحدة حتى تنتقل البيانات من جهاز الإدارة للجميع.
