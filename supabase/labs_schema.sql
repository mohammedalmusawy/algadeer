-- ============================================================
-- غدير كلينك — إصلاح المختبرات / الباقات / التحاليل
-- نفّذه كاملًا مرة واحدة في:
--   Supabase Dashboard → SQL Editor → New query → Run
--
-- ماذا يفعل؟
-- 1) ينشئ analyses + lab_package_analyses إن لم يكونا موجودين
-- 2) يصلّح سياسات RLS للكتابة للمستخدم المسجّل (authenticated)
--    وهذا سبب شائع لرسالة «تعذر الحفظ» عند Insert/Update
-- 3) لا يمس جدول doctors ولا Storage مسار doctors/
--
-- ملاحظة: عمود lab_packages.tests موجود مسبقًا كـ text
-- التطبيق يحفظ فيه JSON نصي مثل: ["CBC","ESR"]
-- ============================================================

-- 1) قاموس التحاليل
create table if not exists public.analyses (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  short_name text,
  description text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index if not exists analyses_name_unique_idx
  on public.analyses (lower(trim(name)));

create index if not exists analyses_is_active_idx
  on public.analyses (is_active);

-- 2) ربط Many-to-Many: باقة ↔ تحاليل
create table if not exists public.lab_package_analyses (
  id uuid primary key default gen_random_uuid(),
  package_id uuid not null references public.lab_packages(id) on delete cascade,
  analysis_id uuid not null references public.analyses(id) on delete restrict,
  display_order integer not null default 0,
  unique (package_id, analysis_id)
);

create index if not exists lab_package_analyses_package_id_idx
  on public.lab_package_analyses (package_id);

create index if not exists lab_package_analyses_analysis_id_idx
  on public.lab_package_analyses (analysis_id);

-- 3) RLS
alter table public.labs enable row level security;
alter table public.lab_packages enable row level security;
alter table public.analyses enable row level security;
alter table public.lab_package_analyses enable row level security;

-- labs
drop policy if exists "labs_public_read_active" on public.labs;
create policy "labs_public_read_active"
  on public.labs for select
  to anon, authenticated
  using (is_active = true or auth.role() = 'authenticated');

drop policy if exists "labs_auth_write" on public.labs;
create policy "labs_auth_write"
  on public.labs for all
  to authenticated
  using (true)
  with check (true);

-- lab_packages  ★ مهم للحفظ
drop policy if exists "lab_packages_public_read_active" on public.lab_packages;
create policy "lab_packages_public_read_active"
  on public.lab_packages for select
  to anon, authenticated
  using (is_active = true or auth.role() = 'authenticated');

drop policy if exists "lab_packages_auth_write" on public.lab_packages;
create policy "lab_packages_auth_write"
  on public.lab_packages for all
  to authenticated
  using (true)
  with check (true);

-- analyses
drop policy if exists "analyses_public_read" on public.analyses;
create policy "analyses_public_read"
  on public.analyses for select
  to anon, authenticated
  using (is_active = true or auth.role() = 'authenticated');

drop policy if exists "analyses_auth_write" on public.analyses;
create policy "analyses_auth_write"
  on public.analyses for all
  to authenticated
  using (true)
  with check (true);

-- lab_package_analyses
drop policy if exists "lab_package_analyses_public_read" on public.lab_package_analyses;
create policy "lab_package_analyses_public_read"
  on public.lab_package_analyses for select
  to anon, authenticated
  using (true);

drop policy if exists "lab_package_analyses_auth_write" on public.lab_package_analyses;
create policy "lab_package_analyses_auth_write"
  on public.lab_package_analyses for all
  to authenticated
  using (true)
  with check (true);

-- 4) Storage لمسار labs/ داخل clinic-media (لا يمس doctors/)
drop policy if exists "clinic_media_labs_public_read" on storage.objects;
create policy "clinic_media_labs_public_read"
  on storage.objects for select
  to anon, authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'labs'
  );

drop policy if exists "clinic_media_labs_auth_insert" on storage.objects;
create policy "clinic_media_labs_auth_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'labs'
  );

drop policy if exists "clinic_media_labs_auth_update" on storage.objects;
create policy "clinic_media_labs_auth_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'labs'
  )
  with check (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'labs'
  );

drop policy if exists "clinic_media_labs_auth_delete" on storage.objects;
create policy "clinic_media_labs_auth_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'labs'
  );

-- 5) تحاليل أولية اختيارية (تُتخطى إن وُجد الاسم)
insert into public.analyses (name, short_name, description, is_active)
select v.name, v.short_name, v.description, true
from (
  values
    ('CBC', 'CBC', 'Complete Blood Count'),
    ('ESR', 'ESR', 'Erythrocyte Sedimentation Rate'),
    ('Blood Sugar', 'BS', 'Blood glucose'),
    ('HbA1c', 'HbA1c', 'Glycated hemoglobin'),
    ('Lipid Profile', 'Lipid', 'Cholesterol panel'),
    ('CRP', 'CRP', 'C-Reactive Protein'),
    ('Creatinine', 'Cr', 'Serum creatinine'),
    ('Calcium', 'Ca', 'Serum calcium'),
    ('Ferritin', 'Ferritin', 'Serum ferritin'),
    ('Vitamin D', 'Vit D', '25-OH Vitamin D'),
    ('Vitamin B12', 'B12', 'Vitamin B12'),
    ('TSH', 'TSH', 'Thyroid stimulating hormone'),
    ('T3', 'T3', 'Triiodothyronine'),
    ('T4', 'T4', 'Thyroxine'),
    ('Zinc', 'Zn', 'Serum zinc'),
    ('Iron', 'Iron', 'Serum iron'),
    ('Folate', 'Folate', 'Folic acid'),
    ('ALT', 'ALT', 'Alanine aminotransferase'),
    ('AST', 'AST', 'Aspartate aminotransferase'),
    ('ALP', 'ALP', 'Alkaline phosphatase'),
    ('Bilirubin', 'Bili', 'Total bilirubin'),
    ('Urea', 'Urea', 'Blood urea'),
    ('Uric Acid', 'UA', 'Uric acid')
) as v(name, short_name, description)
where not exists (
  select 1 from public.analyses a
  where lower(trim(a.name)) = lower(trim(v.name))
);
