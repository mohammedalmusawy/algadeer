-- ============================================================
-- غدير كلينك — مكتبة التحاليل + Aliases + Package Templates
-- نفّذه في Supabase SQL Editor مرة واحدة (Idempotent).
-- لا يحذف بيانات، لا يمس doctors / auth / storage.
-- ============================================================

-- 1) أعمدة إضافية على analyses
alter table public.analyses add column if not exists category text not null default '';
alter table public.analyses add column if not exists name_ar text not null default '';
alter table public.analyses add column if not exists aliases text[] not null default '{}'::text[];
alter table public.analyses add column if not exists search_text text not null default '';

-- 2) جداول القوالب
create table if not exists public.package_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  is_active boolean not null default true,
  display_order integer not null default 0,
  created_at timestamptz not null default now()
);
create unique index if not exists package_templates_name_unique_idx on public.package_templates (lower(trim(name)));
create table if not exists public.package_template_analyses (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.package_templates(id) on delete cascade,
  analysis_id uuid not null references public.analyses(id) on delete restrict,
  display_order integer not null default 0,
  unique (template_id, analysis_id)
);
create index if not exists package_template_analyses_template_id_idx on public.package_template_analyses (template_id);

-- 3) RLS للقوالب
alter table public.package_templates enable row level security;
alter table public.package_template_analyses enable row level security;
drop policy if exists "package_templates_public_read" on public.package_templates;
create policy "package_templates_public_read" on public.package_templates for select to anon, authenticated
  using (is_active = true or auth.role() = 'authenticated');
drop policy if exists "package_templates_auth_write" on public.package_templates;
create policy "package_templates_auth_write" on public.package_templates for all to authenticated
  using (true) with check (true);
drop policy if exists "package_template_analyses_public_read" on public.package_template_analyses;
create policy "package_template_analyses_public_read" on public.package_template_analyses for select to anon, authenticated using (true);
drop policy if exists "package_template_analyses_auth_write" on public.package_template_analyses;
create policy "package_template_analyses_auth_write" on public.package_template_analyses for all to authenticated
  using (true) with check (true);

-- 4) Seed التحاليل (upsert حسب الاسم دون تكرار)
with seed(name, short_name, name_ar, category, description, aliases) as (
  values
  ('CBC', 'CBC', 'صورة الدم الكاملة', 'HEMATOLOGY', 'Complete Blood Count', ARRAY['Complete Blood Count','صورة الدم','تعداد الدم','فحص الدم الكامل','Hemogram']::text[]),
  ('Hemoglobin', 'Hb', 'الهيموغلوبين', 'HEMATOLOGY', 'Hemoglobin', ARRAY['Hb','HGB','هيموغلوبين','هيموجلوبين']::text[]),
  ('Hematocrit', 'HCT', 'الهيماتوكريت', 'HEMATOLOGY', 'Hematocrit', ARRAY['HCT','PCV','هيماتوكريت']::text[]),
  ('RBC Count', 'RBC', 'تعداد كريات الدم الحمراء', 'HEMATOLOGY', 'Red blood cell count', ARRAY['RBC','Red Blood Cells','كريات حمراء']::text[]),
  ('WBC Count', 'WBC', 'تعداد كريات الدم البيضاء', 'HEMATOLOGY', 'White blood cell count', ARRAY['WBC','White Blood Cells','كريات بيضاء','Leukocytes']::text[]),
  ('Platelet Count', 'PLT', 'الصفائح الدموية', 'HEMATOLOGY', 'Platelet count', ARRAY['PLT','Platelets','صفائح','صفائح دموية']::text[]),
  ('ESR', 'ESR', 'سرعة الترسيب', 'HEMATOLOGY', 'Erythrocyte Sedimentation Rate', ARRAY['Erythrocyte Sedimentation Rate','سرعة ترسيب','ترسيب']::text[]),
  ('Reticulocyte Count', 'Retic', 'الشبكيات', 'HEMATOLOGY', 'Reticulocyte count', ARRAY['Reticulocytes','الشبكيات','ريتكيولوسايت']::text[]),
  ('Peripheral Blood Film', 'PBF', 'مسحة الدم', 'HEMATOLOGY', 'Peripheral blood smear', ARRAY['Blood Smear','Peripheral Smear','مسحة دم','فيلم دم']::text[]),
  ('Blood Group ABO', 'ABO', 'فصيلة الدم', 'HEMATOLOGY', 'ABO blood group', ARRAY['Blood Group','فصيلة','زمرة الدم','ABO']::text[]),
  ('Rh Factor', 'Rh', 'عامل ريسس', 'HEMATOLOGY', 'Rh factor', ARRAY['Rh','Rhesus','ريسس']::text[]),
  ('Sickle Cell Screen', 'Sickle', 'فحص الخلايا المنجلية', 'HEMATOLOGY', 'Sickle cell screening', ARRAY['Sickling Test','منجلي','Sickle']::text[]),
  ('Hb Electrophoresis', 'HbEP', 'ترحيل الهيموغلوبين', 'HEMATOLOGY', 'Hemoglobin electrophoresis', ARRAY['Hemoglobin Electrophoresis','ترحيل خضاب']::text[]),
  ('G6PD', 'G6PD', 'نقص نازعة هيدروجين الجلوكوز', 'HEMATOLOGY', 'G6PD assay', ARRAY['Glucose-6-Phosphate Dehydrogenase','جي6بي دي']::text[]),
  ('Coombs Direct', 'DAT', 'كومبس مباشر', 'HEMATOLOGY', 'Direct antiglobulin test', ARRAY['DAT','Direct Coombs','كومبس']::text[]),
  ('Coombs Indirect', 'IAT', 'كومبس غير مباشر', 'HEMATOLOGY', 'Indirect antiglobulin test', ARRAY['IAT','Indirect Coombs']::text[]),
  ('PT', 'PT', 'زمن البروثرومبين', 'COAGULATION', 'Prothrombin Time', ARRAY['Prothrombin Time','بروثرومبين']::text[]),
  ('INR', 'INR', 'النسبة المعيارية الدولية', 'COAGULATION', 'International Normalized Ratio', ARRAY['International Normalized Ratio']::text[]),
  ('aPTT', 'aPTT', 'زمن الثرومبوبلاستين الجزئي', 'COAGULATION', 'Activated partial thromboplastin time', ARRAY['PTT','Partial Thromboplastin Time']::text[]),
  ('Fibrinogen', 'FIB', 'الفيبرينوجين', 'COAGULATION', 'Fibrinogen', ARRAY['Factor I','فيبرينوجين']::text[]),
  ('D-Dimer', 'D-Dimer', 'دي دايمر', 'COAGULATION', 'D-Dimer', ARRAY['D Dimer','دي-دايمر','DDimer']::text[]),
  ('Bleeding Time', 'BT', 'زمن النزف', 'COAGULATION', 'Bleeding time', ARRAY['زمن نزف']::text[]),
  ('Clotting Time', 'CT', 'زمن التخثر', 'COAGULATION', 'Clotting time', ARRAY['زمن تجلط','زمن التخثر']::text[]),
  ('FBS', 'FBS', 'السكر الصائم', 'DIABETES', 'Fasting blood sugar', ARRAY['Fasting Blood Sugar','Blood Sugar','BS','سكر صائم','سكر','جلوكوز صائم','Glucose Fasting']::text[]),
  ('RBS', 'RBS', 'السكر العشوائي', 'DIABETES', 'Random blood sugar', ARRAY['Random Blood Sugar','سكر عشوائي','جلوكوز عشوائي']::text[]),
  ('PPBS', 'PPBS', 'السكر بعد الأكل', 'DIABETES', 'Postprandial blood sugar', ARRAY['Postprandial Blood Sugar','سكر بعد الأكل','سكر بعد الوجبة']::text[]),
  ('HbA1c', 'HbA1c', 'السكر التراكمي', 'DIABETES', 'Glycated hemoglobin', ARRAY['A1C','Glycated Hemoglobin','السكر التراكمي','سكر تراكمي','هيموغلوبين سكري']::text[]),
  ('OGTT', 'OGTT', 'اختبار تحمل الجلوكوز', 'DIABETES', 'Oral glucose tolerance test', ARRAY['Glucose Tolerance Test','تحمل السكر']::text[]),
  ('Fasting Insulin', 'F.Insulin', 'الإنسولين الصائم', 'DIABETES', 'Fasting insulin', ARRAY['Insulin Fasting','انسولين صائم']::text[]),
  ('Insulin', 'Insulin', 'الإنسولين', 'DIABETES', 'Insulin', ARRAY['انسولين','إنسولين']::text[]),
  ('C-Peptide', 'C-Peptide', 'سي ببتايد', 'DIABETES', 'C-Peptide', ARRAY['C Peptide','سي بيبتايد']::text[]),
  ('HOMA-IR', 'HOMA-IR', 'مقاومة الإنسولين', 'DIABETES', 'HOMA-IR index', ARRAY['HOMA IR','مقاومة انسولين','مقاومة الإنسولين']::text[]),
  ('Urea', 'Urea', 'اليوريا', 'KIDNEY', 'Blood urea', ARRAY['BUN','Blood Urea','يوريا','وظائف الكلى']::text[]),
  ('Creatinine', 'Cr', 'الكرياتينين', 'KIDNEY', 'Serum creatinine', ARRAY['كرياتينين','كلية','كلى','وظائف الكلى']::text[]),
  ('eGFR', 'eGFR', 'معدل الترشيح الكبيبي', 'KIDNEY', 'Estimated GFR', ARRAY['GFR','Estimated GFR','ترشيح كبيبي']::text[]),
  ('Uric Acid', 'UA', 'حمض اليوريك', 'KIDNEY', 'Uric acid', ARRAY['Urate','يوريك','نقرس']::text[]),
  ('Urine Microalbumin', 'U.MA', 'الألبومين الميكروي بالبول', 'KIDNEY', 'Urine microalbumin', ARRAY['Microalbumin','مايكروألبومين','زلال دقيق']::text[]),
  ('Urine ACR', 'ACR', 'نسبة الألبومين إلى الكرياتينين', 'KIDNEY', 'Albumin/Creatinine ratio', ARRAY['Albumin/Creatinine Ratio','ACR','نسبة الزلال']::text[]),
  ('24 Hour Urine Protein', '24h UP', 'بروتين بول 24 ساعة', 'KIDNEY', '24-hour urine protein', ARRAY['24h Urine Protein','بروتين 24 ساعة']::text[]),
  ('Creatinine Clearance', 'CrCl', 'تصفية الكرياتينين', 'KIDNEY', 'Creatinine clearance', ARRAY['Clearance','تصفية']::text[]),
  ('Sodium', 'Na', 'الصوديوم', 'ELECTROLYTES', 'Sodium', ARRAY['Na','صوديوم']::text[]),
  ('Potassium', 'K', 'البوتاسيوم', 'ELECTROLYTES', 'Potassium', ARRAY['K','بوتاسيوم']::text[]),
  ('Chloride', 'Cl', 'الكلوريد', 'ELECTROLYTES', 'Chloride', ARRAY['Cl','كلور']::text[]),
  ('Calcium', 'Ca', 'الكالسيوم', 'ELECTROLYTES', 'Serum calcium', ARRAY['Ca','كالسيوم']::text[]),
  ('Ionized Calcium', 'iCa', 'الكالسيوم المتأين', 'ELECTROLYTES', 'Ionized calcium', ARRAY['Free Calcium','كالسيوم متأين']::text[]),
  ('Magnesium', 'Mg', 'المغنيسيوم', 'ELECTROLYTES', 'Magnesium', ARRAY['Mg','مغنيسيوم','مغنسيوم']::text[]),
  ('Phosphorus', 'Phos', 'الفوسفور', 'ELECTROLYTES', 'Phosphate', ARRAY['Phosphate','PO4','فوسفور','فوسفات']::text[]),
  ('Zinc', 'Zn', 'الزنك', 'ELECTROLYTES', 'Zinc', ARRAY['Zn','زنك']::text[]),
  ('Copper', 'Cu', 'النحاس', 'ELECTROLYTES', 'Copper', ARRAY['Cu','نحاس']::text[]),
  ('ALT', 'ALT', 'إنزيم الكبد ALT', 'LIVER', 'Alanine aminotransferase', ARRAY['GPT','SGPT','Alanine Aminotransferase','ALT/GPT']::text[]),
  ('AST', 'AST', 'إنزيم الكبد AST', 'LIVER', 'Aspartate aminotransferase', ARRAY['GOT','SGOT','Aspartate Aminotransferase','AST/GOT']::text[]),
  ('ALP', 'ALP', 'الفوسفاتاز القلوي', 'LIVER', 'Alkaline phosphatase', ARRAY['Alkaline Phosphatase','فوسفاتاز']::text[]),
  ('GGT', 'GGT', 'إنزيم GGT', 'LIVER', 'Gamma-glutamyl transferase', ARRAY['Gamma GT','γ-GT','جي جي تي']::text[]),
  ('Total Bilirubin', 'T.Bili', 'البيليروبين الكلي', 'LIVER', 'Total bilirubin', ARRAY['Bilirubin','Total Bili','بيليروبين','صفراء']::text[]),
  ('Direct Bilirubin', 'D.Bili', 'البيليروبين المباشر', 'LIVER', 'Direct bilirubin', ARRAY['Conjugated Bilirubin','بيليروبين مباشر']::text[]),
  ('Indirect Bilirubin', 'I.Bili', 'البيليروبين غير المباشر', 'LIVER', 'Indirect bilirubin', ARRAY['Unconjugated Bilirubin','بيليروبين غير مباشر']::text[]),
  ('Albumin', 'Alb', 'الألبومين', 'LIVER', 'Albumin', ARRAY['Serum Albumin','ألبومين','زلال']::text[]),
  ('Total Protein', 'TP', 'البروتين الكلي', 'LIVER', 'Total protein', ARRAY['Serum Protein','بروتين كلي']::text[]),
  ('Globulin', 'Glob', 'الغلوبولين', 'LIVER', 'Globulin', ARRAY['غلوبولين']::text[]),
  ('A/G Ratio', 'A/G', 'نسبة الألبومين للغلوبولين', 'LIVER', 'Albumin/Globulin ratio', ARRAY['AG Ratio','نسبة A/G']::text[]),
  ('Total Cholesterol', 'TC', 'الكوليسترول الكلي', 'LIPIDS', 'Total cholesterol', ARRAY['Cholesterol','كوليسترول','كوليسترول كلي','Lipid Profile','دهون']::text[]),
  ('Triglycerides', 'TG', 'الدهون الثلاثية', 'LIPIDS', 'Triglycerides', ARRAY['TG','ثلاثي الغليسريد','دهون ثلاثية','Triglyceride']::text[]),
  ('HDL', 'HDL', 'الكوليسترول النافع', 'LIPIDS', 'HDL cholesterol', ARRAY['HDL-C','كوليسترول نافع','HDL Cholesterol']::text[]),
  ('LDL', 'LDL', 'الكوليسترول الضار', 'LIPIDS', 'LDL cholesterol', ARRAY['LDL-C','كوليسترول ضار','LDL Cholesterol']::text[]),
  ('VLDL', 'VLDL', 'كوليسترول VLDL', 'LIPIDS', 'VLDL cholesterol', ARRAY['VLDL-C']::text[]),
  ('Non-HDL Cholesterol', 'Non-HDL', 'كوليسترول غير HDL', 'LIPIDS', 'Non-HDL cholesterol', ARRAY['Non HDL']::text[]),
  ('Apolipoprotein A1', 'ApoA1', 'أبوليبوبروتين A1', 'LIPIDS', 'Apolipoprotein A1', ARRAY['Apo A1','ApoA-I']::text[]),
  ('Apolipoprotein B', 'ApoB', 'أبوليبوبروتين B', 'LIPIDS', 'Apolipoprotein B', ARRAY['Apo B','ApoB-100']::text[]),
  ('Lipoprotein(a)', 'Lp(a)', 'ليبوبورتين أ', 'LIPIDS', 'Lipoprotein(a)', ARRAY['Lp(a)','LPA','Lipoprotein a']::text[]),
  ('TSH', 'TSH', 'الهرمون المحفز للغدة الدرقية', 'THYROID', 'Thyroid stimulating hormone', ARRAY['Thyroid','الغدة','الغدة الدرقية','هرمون الغدة','Thyroid Stimulating Hormone']::text[]),
  ('T3', 'T3', 'هرمون T3', 'THYROID', 'Triiodothyronine', ARRAY['Total T3','Triiodothyronine']::text[]),
  ('T4', 'T4', 'هرمون T4', 'THYROID', 'Thyroxine', ARRAY['Total T4','Thyroxine']::text[]),
  ('Free T3', 'FT3', 'T3 الحر', 'THYROID', 'Free T3', ARRAY['FT3','Free Triiodothyronine','تي3 حر']::text[]),
  ('Free T4', 'FT4', 'T4 الحر', 'THYROID', 'Free T4', ARRAY['FT4','Free Thyroxine','تي4 حر']::text[]),
  ('Anti-TPO', 'Anti-TPO', 'أجسام مضادة لـ TPO', 'THYROID', 'Anti-thyroid peroxidase', ARRAY['TPO Ab','Anti TPO','مضاد TPO']::text[]),
  ('Anti-Thyroglobulin', 'Anti-TG', 'أجسام مضادة للثيروغلوبيولين', 'THYROID', 'Anti-thyroglobulin', ARRAY['Anti-TG','TG Ab','Anti TG']::text[]),
  ('Thyroglobulin', 'Thyroglob', 'الثيروغلوبيولين', 'THYROID', 'Thyroglobulin', ARRAY['TG','ثيروغلوبيولين']::text[]),
  ('TRAb', 'TRAb', 'أجسام مضادة لمستقبلات TSH', 'THYROID', 'TSH receptor antibodies', ARRAY['TSH Receptor Antibody']::text[]),
  ('Serum Iron', 'Iron', 'الحديد في الدم', 'IRON', 'Serum iron', ARRAY['Iron','حديد','Fe']::text[]),
  ('Ferritin', 'Ferritin', 'مخزون الحديد', 'IRON', 'Ferritin', ARRAY['مخزون الحديد','خزين الحديد','حديد مخزون','فيريتين']::text[]),
  ('TIBC', 'TIBC', 'سعة ارتباط الحديد الكلية', 'IRON', 'Total iron binding capacity', ARRAY['Total Iron Binding Capacity']::text[]),
  ('UIBC', 'UIBC', 'سعة ارتباط الحديد غير المشبعة', 'IRON', 'Unsaturated iron binding capacity', ARRAY['Unsaturated Iron Binding Capacity']::text[]),
  ('Transferrin', 'Transferrin', 'الترانسفيرين', 'IRON', 'Transferrin', ARRAY['ترانسفيرين']::text[]),
  ('Transferrin Saturation', 'TSAT', 'تشبع الترانسفيرين', 'IRON', 'Transferrin saturation', ARRAY['TSAT','% Saturation','تشبع الحديد']::text[]),
  ('Vitamin B12', 'B12', 'فيتامين ب12', 'VITAMINS', 'Vitamin B12', ARRAY['B12','Cobalamin','فيتامين B12','فيتامين بي 12']::text[]),
  ('Folate', 'Folate', 'حمض الفوليك', 'VITAMINS', 'Folate / Vitamin B9', ARRAY['Folic Acid','Vitamin B9','B9','فولات','فوليك']::text[]),
  ('Vitamin D', 'Vit D', 'فيتامين د', 'VITAMINS', '25-OH Vitamin D', ARRAY['Vit D','D3','25-OH Vitamin D','25 OH D','فيتامين دي','فيتامين دال','Vitamin D3']::text[]),
  ('Vitamin A', 'Vit A', 'فيتامين أ', 'VITAMINS', 'Vitamin A', ARRAY['Retinol','فيتامين A']::text[]),
  ('Vitamin E', 'Vit E', 'فيتامين هـ', 'VITAMINS', 'Vitamin E', ARRAY['Tocopherol','فيتامين E']::text[]),
  ('CRP', 'CRP', 'بروتين سي التفاعلي', 'INFLAMMATION', 'C-Reactive Protein', ARRAY['C-Reactive Protein','سي آر بي','التهاب']::text[]),
  ('hs-CRP', 'hs-CRP', 'بروتين سي عالي الحساسية', 'INFLAMMATION', 'High-sensitivity CRP', ARRAY['High Sensitivity CRP','hsCRP']::text[]),
  ('Procalcitonin', 'PCT', 'البروكالسيتونين', 'INFLAMMATION', 'Procalcitonin', ARRAY['PCT','بروكالسيتونين']::text[]),
  ('RF', 'RF', 'عامل الروماتويد', 'RHEUMATOLOGY', 'Rheumatoid factor', ARRAY['Rheumatoid Factor','روماتويد']::text[]),
  ('Anti-CCP', 'Anti-CCP', 'مضاد CCP', 'RHEUMATOLOGY', 'Anti-CCP antibodies', ARRAY['CCP','Anti CCP','ACPA']::text[]),
  ('ANA', 'ANA', 'الأجسام المضادة للنواة', 'RHEUMATOLOGY', 'Antinuclear antibodies', ARRAY['Antinuclear Antibody','ANA Screen']::text[]),
  ('Anti-dsDNA', 'dsDNA', 'مضاد الحمض النووي', 'RHEUMATOLOGY', 'Anti-double stranded DNA', ARRAY['Anti dsDNA','Anti-DNA']::text[]),
  ('C3', 'C3', 'المتممة C3', 'RHEUMATOLOGY', 'Complement C3', ARRAY['Complement C3']::text[]),
  ('C4', 'C4', 'المتممة C4', 'RHEUMATOLOGY', 'Complement C4', ARRAY['Complement C4']::text[]),
  ('ASO', 'ASO', 'مضاد الستربتوليزين', 'RHEUMATOLOGY', 'Antistreptolysin O', ARRAY['ASOT','Antistreptolysin O','آسو']::text[]),
  ('Troponin I', 'TnI', 'تروبونين I', 'CARDIAC', 'Troponin I', ARRAY['cTnI','Troponin-I','تروبونين']::text[]),
  ('Troponin T', 'TnT', 'تروبونين T', 'CARDIAC', 'Troponin T', ARRAY['cTnT','Troponin-T']::text[]),
  ('High-Sensitivity Troponin', 'hs-Tn', 'تروبونين عالي الحساسية', 'CARDIAC', 'High-sensitivity troponin', ARRAY['hsTroponin','hs-cTn']::text[]),
  ('CK', 'CK', 'كرياتين كاينيز', 'CARDIAC', 'Creatine kinase', ARRAY['CPK','Creatine Kinase']::text[]),
  ('CK-MB', 'CK-MB', 'كرياتين كاينيز MB', 'CARDIAC', 'CK-MB isoenzyme', ARRAY['CKMB','CPK-MB']::text[]),
  ('LDH', 'LDH', 'نازعة لاكتات', 'CARDIAC', 'Lactate dehydrogenase', ARRAY['Lactate Dehydrogenase']::text[]),
  ('BNP', 'BNP', 'بيتا ناتريوتيك', 'CARDIAC', 'B-type natriuretic peptide', ARRAY['B-type Natriuretic Peptide']::text[]),
  ('NT-proBNP', 'NT-proBNP', 'إن تي برو بي إن بي', 'CARDIAC', 'N-terminal pro-BNP', ARRAY['NTproBNP']::text[]),
  ('Myoglobin', 'Myo', 'الميوغلوبين', 'CARDIAC', 'Myoglobin', ARRAY['ميوغلوبين']::text[]),
  ('Amylase', 'AMY', 'الأميليز', 'PANCREAS', 'Amylase', ARRAY['Serum Amylase','أميليز']::text[]),
  ('Lipase', 'LIP', 'الليباز', 'PANCREAS', 'Lipase', ARRAY['Serum Lipase','ليباز']::text[]),
  ('Testosterone Total', 'Testo', 'التستوستيرون الكلي', 'HORMONES', 'Total testosterone', ARRAY['Testosterone','Total Testosterone','تستوستيرون']::text[]),
  ('Free Testosterone', 'Free Testo', 'التستوستيرون الحر', 'HORMONES', 'Free testosterone', ARRAY['Free Testo','تستوستيرون حر']::text[]),
  ('Estradiol', 'E2', 'الإستراديول', 'HORMONES', 'Estradiol', ARRAY['E2','Oestradiol','استراديول']::text[]),
  ('Progesterone', 'Prog', 'البروجستيرون', 'HORMONES', 'Progesterone', ARRAY['بروجستيرون']::text[]),
  ('Prolactin', 'PRL', 'البرولاكتين', 'HORMONES', 'Prolactin', ARRAY['PRL','برولاكتين']::text[]),
  ('FSH', 'FSH', 'الهرمون المنبه للجريب', 'HORMONES', 'Follicle stimulating hormone', ARRAY['Follicle Stimulating Hormone']::text[]),
  ('LH', 'LH', 'الهرمون المنبه للجسم الأصفر', 'HORMONES', 'Luteinizing hormone', ARRAY['Luteinizing Hormone']::text[]),
  ('Cortisol', 'Cortisol', 'الكورتيزول', 'HORMONES', 'Cortisol', ARRAY['كورتيزول']::text[]),
  ('ACTH', 'ACTH', 'الهرمون الموجه لقشرة الكظر', 'HORMONES', 'ACTH', ARRAY['Adrenocorticotropic Hormone']::text[]),
  ('DHEA-S', 'DHEA-S', 'ديهيدرو إيبي أندروستيرون', 'HORMONES', 'DHEA-S', ARRAY['DHEAS','DHEA Sulfate']::text[]),
  ('SHBG', 'SHBG', 'الغلوبيولين الرابط للهرمونات الجنسية', 'HORMONES', 'Sex hormone binding globulin', ARRAY['Sex Hormone Binding Globulin']::text[]),
  ('Growth Hormone', 'GH', 'هرمون النمو', 'HORMONES', 'Growth hormone', ARRAY['GH','HGH','هرمون النمو']::text[]),
  ('IGF-1', 'IGF-1', 'عامل النمو الشبيه بالإنسولين', 'HORMONES', 'IGF-1', ARRAY['IGF1','Somatomedin C']::text[]),
  ('PTH', 'PTH', 'هرمون جارات الدرق', 'HORMONES', 'Parathyroid hormone', ARRAY['Parathyroid Hormone','باراثورمون']::text[]),
  ('Beta-hCG Quantitative', 'β-hCG', 'هرمون الحمل الكمي', 'FERTILITY', 'Quantitative beta-hCG', ARRAY['Beta hCG','hCG Quantitative','بيتا HCG','حمل كمي']::text[]),
  ('Pregnancy Test', 'hCG Qual', 'اختبار الحمل', 'FERTILITY', 'Qualitative hCG', ARRAY['hCG Qualitative','اختبار حمل','حمل']::text[]),
  ('AMH', 'AMH', 'مخزون المبيض', 'FERTILITY', 'Anti-Mullerian hormone', ARRAY['Anti-Mullerian Hormone','مخزون مبايض']::text[]),
  ('Semen Analysis', 'Semen', 'تحليل السائل المنوي', 'FERTILITY', 'Semen analysis', ARRAY['Sperm Analysis','سائل منوي']::text[]),
  ('PSA Total', 'PSA', 'مستضد البروستات الكلي', 'PROSTATE', 'Total PSA', ARRAY['PSA','Prostate Specific Antigen','بروستات']::text[]),
  ('PSA Free', 'fPSA', 'مستضد البروستات الحر', 'PROSTATE', 'Free PSA', ARRAY['Free PSA']::text[]),
  ('Free/Total PSA Ratio', 'f/t PSA', 'نسبة PSA الحر للكلي', 'PROSTATE', 'Free/Total PSA ratio', ARRAY['PSA Ratio','نسبة PSA']::text[]),
  ('General Urine Examination', 'GUE', 'تحليل الإدرار العام', 'URINE', 'General urine examination', ARRAY['Urinalysis','UE','تحليل بول','إدرار','بول عام']::text[]),
  ('Urine Culture', 'U.Culture', 'زرع الإدرار', 'URINE', 'Urine culture', ARRAY['Culture Urine','زرع بول']::text[]),
  ('Urine Protein', 'U.Prot', 'بروتين البول', 'URINE', 'Urine protein', ARRAY['Proteinuria','بروتين بول']::text[]),
  ('Urine Glucose', 'U.Glu', 'سكر البول', 'URINE', 'Urine glucose', ARRAY['Glycosuria','سكر بول']::text[]),
  ('Urine Ketones', 'U.Ket', 'كيتون البول', 'URINE', 'Urine ketones', ARRAY['Ketonuria','كيتونات']::text[]),
  ('General Stool Examination', 'GSE', 'تحليل البراز العام', 'STOOL', 'General stool examination', ARRAY['Stool Analysis','تحليل براز','براز']::text[]),
  ('Stool Culture', 'S.Culture', 'زرع البراز', 'STOOL', 'Stool culture', ARRAY['Culture Stool','زرع براز']::text[]),
  ('Occult Blood', 'FOBT', 'الدم الخفي في البراز', 'STOOL', 'Fecal occult blood', ARRAY['FOBT','Fecal Occult Blood','دم خفي']::text[]),
  ('H. pylori Stool Antigen', 'H.pylori Ag', 'مستضد جرثومة المعدة بالبراز', 'STOOL', 'H. pylori stool antigen', ARRAY['Helicobacter Pylori Antigen','جرثومة المعدة','هليكوباكتر']::text[]),
  ('Calprotectin', 'Calprotectin', 'الكالبروتكتين', 'STOOL', 'Fecal calprotectin', ARRAY['Fecal Calprotectin']::text[]),
  ('Ova & Parasites', 'O&P', 'الديدان والطفيليات', 'STOOL', 'Ova and parasites', ARRAY['Parasites','طفيليات','ديدان']::text[]),
  ('H. pylori Antibody', 'H.pylori Ab', 'أجسام مضادة لجرثومة المعدة', 'INFECTIOUS', 'H. pylori antibody', ARRAY['H.pylori Ab','Helicobacter Antibody']::text[]),
  ('H. pylori IgG', 'H.pylori IgG', 'IgG لجرثومة المعدة', 'INFECTIOUS', 'H. pylori IgG', ARRAY['Helicobacter IgG']::text[]),
  ('H. pylori Breath Test', 'UBT', 'اختبار النفس لجرثومة المعدة', 'INFECTIOUS', 'Urea breath test', ARRAY['Urea Breath Test','اختبار نفس']::text[]),
  ('HBsAg', 'HBsAg', 'مستضد التهاب الكبد B', 'HEPATITIS', 'Hepatitis B surface antigen', ARRAY['Hepatitis B Surface Antigen','التهاب الكبد B']::text[]),
  ('Anti-HBs', 'Anti-HBs', 'مضاد HBs', 'HEPATITIS', 'Hepatitis B surface antibody', ARRAY['HBsAb','Anti HBs']::text[]),
  ('Anti-HBc Total', 'Anti-HBc', 'مضاد HBc الكلي', 'HEPATITIS', 'Total anti-HBc', ARRAY['HBcAb Total','Anti HBc']::text[]),
  ('Anti-HBc IgM', 'HBc IgM', 'مضاد HBc من نوع IgM', 'HEPATITIS', 'Anti-HBc IgM', ARRAY['HBcIgM']::text[]),
  ('HBeAg', 'HBeAg', 'مستضد HBe', 'HEPATITIS', 'Hepatitis B e antigen', ARRAY['HBe Antigen']::text[]),
  ('Anti-HBe', 'Anti-HBe', 'مضاد HBe', 'HEPATITIS', 'Hepatitis B e antibody', ARRAY['HBeAb']::text[]),
  ('HCV Ab', 'HCV Ab', 'أجسام مضادة لالتهاب الكبد C', 'HEPATITIS', 'Hepatitis C antibody', ARRAY['Anti-HCV','HCV','التهاب الكبد C']::text[]),
  ('HIV Ag/Ab', 'HIV', 'فحص فيروس نقص المناعة', 'HEPATITIS', 'HIV antigen/antibody', ARRAY['HIV','HIV Combo','ايدز']::text[]),
  ('HAV IgM', 'HAV IgM', 'التهاب الكبد A IgM', 'HEPATITIS', 'Hepatitis A IgM', ARRAY['Hepatitis A IgM']::text[]),
  ('HAV IgG', 'HAV IgG', 'التهاب الكبد A IgG', 'HEPATITIS', 'Hepatitis A IgG', ARRAY['Hepatitis A IgG']::text[]),
  ('VDRL', 'VDRL', 'فحص الزهري VDRL', 'SEROLOGY', 'VDRL syphilis test', ARRAY['Syphilis VDRL']::text[]),
  ('RPR', 'RPR', 'فحص الزهري RPR', 'SEROLOGY', 'Rapid plasma reagin', ARRAY['Syphilis RPR']::text[]),
  ('TPHA', 'TPHA', 'تأكيد الزهري TPHA', 'SEROLOGY', 'TPHA', ARRAY['Treponema Pallidum']::text[]),
  ('Brucella', 'Brucella', 'البروسيلا', 'SEROLOGY', 'Brucella serology', ARRAY['بروسيلا','مالطا']::text[]),
  ('Widal', 'Widal', 'ويدال', 'SEROLOGY', 'Widal test', ARRAY['Typhoid','تيفوئيد','ويدال']::text[]),
  ('Toxoplasma IgG', 'Toxo IgG', 'توكسوبلازما IgG', 'SEROLOGY', 'Toxoplasma IgG', ARRAY['Toxoplasma']::text[]),
  ('Toxoplasma IgM', 'Toxo IgM', 'توكسوبلازما IgM', 'SEROLOGY', 'Toxoplasma IgM', ARRAY['Toxo IgM']::text[]),
  ('CMV IgG', 'CMV IgG', 'فيروس CMV IgG', 'SEROLOGY', 'CMV IgG', ARRAY['Cytomegalovirus IgG']::text[]),
  ('CMV IgM', 'CMV IgM', 'فيروس CMV IgM', 'SEROLOGY', 'CMV IgM', ARRAY['Cytomegalovirus IgM']::text[]),
  ('Rubella IgG', 'Rubella IgG', 'الحصبة الألمانية IgG', 'SEROLOGY', 'Rubella IgG', ARRAY['حصبة ألمانية']::text[]),
  ('Rubella IgM', 'Rubella IgM', 'الحصبة الألمانية IgM', 'SEROLOGY', 'Rubella IgM', ARRAY['Rubella']::text[]),
  ('EBV', 'EBV', 'فيروس إبشتاين بار', 'SEROLOGY', 'Epstein-Barr virus serology', ARRAY['Epstein-Barr','EBV VCA']::text[]),
  ('Blood Culture', 'B.Culture', 'زرع الدم', 'CULTURE', 'Blood culture', ARRAY['Culture Blood','زرع دم']::text[]),
  ('Sputum Culture', 'Sp.Culture', 'زرع القشع', 'CULTURE', 'Sputum culture', ARRAY['Culture Sputum']::text[]),
  ('Throat Swab Culture', 'Throat', 'زرع مسحة الحلق', 'CULTURE', 'Throat swab culture', ARRAY['Throat Culture','حلق']::text[]),
  ('Wound Culture', 'Wound', 'زرع الجرح', 'CULTURE', 'Wound culture', ARRAY['Culture Wound']::text[]),
  ('High Vaginal Swab Culture', 'HVS', 'زرع المسحة المهبلية', 'CULTURE', 'High vaginal swab culture', ARRAY['HVS Culture','مسحة مهبلية']::text[]),
  ('Lactate', 'Lactate', 'اللاكتات', 'OTHER', 'Lactate', ARRAY['Lactic Acid','لاكتات']::text[]),
  ('Ammonia', 'NH3', 'الأمونيا', 'OTHER', 'Ammonia', ARRAY['NH3','امونيا']::text[]),
  ('Ceruloplasmin', 'Cp', 'السيرولوبلازمين', 'OTHER', 'Ceruloplasmin', ARRAY['سيرولوبلازمين']::text[])
)
insert into public.analyses (name, short_name, name_ar, category, description, aliases, is_active)
select s.name, s.short_name, s.name_ar, s.category, s.description, s.aliases, true
from seed s
where not exists (
  select 1 from public.analyses a where lower(trim(a.name)) = lower(trim(s.name))
);

-- تحديث الحقول للتحاليل الموجودة مسبقًا (بدون تغيير الاسم)
with seed(name, short_name, name_ar, category, description, aliases) as (
  values
  ('CBC', 'CBC', 'صورة الدم الكاملة', 'HEMATOLOGY', 'Complete Blood Count', ARRAY['Complete Blood Count','صورة الدم','تعداد الدم','فحص الدم الكامل','Hemogram']::text[]),
  ('Hemoglobin', 'Hb', 'الهيموغلوبين', 'HEMATOLOGY', 'Hemoglobin', ARRAY['Hb','HGB','هيموغلوبين','هيموجلوبين']::text[]),
  ('Hematocrit', 'HCT', 'الهيماتوكريت', 'HEMATOLOGY', 'Hematocrit', ARRAY['HCT','PCV','هيماتوكريت']::text[]),
  ('RBC Count', 'RBC', 'تعداد كريات الدم الحمراء', 'HEMATOLOGY', 'Red blood cell count', ARRAY['RBC','Red Blood Cells','كريات حمراء']::text[]),
  ('WBC Count', 'WBC', 'تعداد كريات الدم البيضاء', 'HEMATOLOGY', 'White blood cell count', ARRAY['WBC','White Blood Cells','كريات بيضاء','Leukocytes']::text[]),
  ('Platelet Count', 'PLT', 'الصفائح الدموية', 'HEMATOLOGY', 'Platelet count', ARRAY['PLT','Platelets','صفائح','صفائح دموية']::text[]),
  ('ESR', 'ESR', 'سرعة الترسيب', 'HEMATOLOGY', 'Erythrocyte Sedimentation Rate', ARRAY['Erythrocyte Sedimentation Rate','سرعة ترسيب','ترسيب']::text[]),
  ('Reticulocyte Count', 'Retic', 'الشبكيات', 'HEMATOLOGY', 'Reticulocyte count', ARRAY['Reticulocytes','الشبكيات','ريتكيولوسايت']::text[]),
  ('Peripheral Blood Film', 'PBF', 'مسحة الدم', 'HEMATOLOGY', 'Peripheral blood smear', ARRAY['Blood Smear','Peripheral Smear','مسحة دم','فيلم دم']::text[]),
  ('Blood Group ABO', 'ABO', 'فصيلة الدم', 'HEMATOLOGY', 'ABO blood group', ARRAY['Blood Group','فصيلة','زمرة الدم','ABO']::text[]),
  ('Rh Factor', 'Rh', 'عامل ريسس', 'HEMATOLOGY', 'Rh factor', ARRAY['Rh','Rhesus','ريسس']::text[]),
  ('Sickle Cell Screen', 'Sickle', 'فحص الخلايا المنجلية', 'HEMATOLOGY', 'Sickle cell screening', ARRAY['Sickling Test','منجلي','Sickle']::text[]),
  ('Hb Electrophoresis', 'HbEP', 'ترحيل الهيموغلوبين', 'HEMATOLOGY', 'Hemoglobin electrophoresis', ARRAY['Hemoglobin Electrophoresis','ترحيل خضاب']::text[]),
  ('G6PD', 'G6PD', 'نقص نازعة هيدروجين الجلوكوز', 'HEMATOLOGY', 'G6PD assay', ARRAY['Glucose-6-Phosphate Dehydrogenase','جي6بي دي']::text[]),
  ('Coombs Direct', 'DAT', 'كومبس مباشر', 'HEMATOLOGY', 'Direct antiglobulin test', ARRAY['DAT','Direct Coombs','كومبس']::text[]),
  ('Coombs Indirect', 'IAT', 'كومبس غير مباشر', 'HEMATOLOGY', 'Indirect antiglobulin test', ARRAY['IAT','Indirect Coombs']::text[]),
  ('PT', 'PT', 'زمن البروثرومبين', 'COAGULATION', 'Prothrombin Time', ARRAY['Prothrombin Time','بروثرومبين']::text[]),
  ('INR', 'INR', 'النسبة المعيارية الدولية', 'COAGULATION', 'International Normalized Ratio', ARRAY['International Normalized Ratio']::text[]),
  ('aPTT', 'aPTT', 'زمن الثرومبوبلاستين الجزئي', 'COAGULATION', 'Activated partial thromboplastin time', ARRAY['PTT','Partial Thromboplastin Time']::text[]),
  ('Fibrinogen', 'FIB', 'الفيبرينوجين', 'COAGULATION', 'Fibrinogen', ARRAY['Factor I','فيبرينوجين']::text[]),
  ('D-Dimer', 'D-Dimer', 'دي دايمر', 'COAGULATION', 'D-Dimer', ARRAY['D Dimer','دي-دايمر','DDimer']::text[]),
  ('Bleeding Time', 'BT', 'زمن النزف', 'COAGULATION', 'Bleeding time', ARRAY['زمن نزف']::text[]),
  ('Clotting Time', 'CT', 'زمن التخثر', 'COAGULATION', 'Clotting time', ARRAY['زمن تجلط','زمن التخثر']::text[]),
  ('FBS', 'FBS', 'السكر الصائم', 'DIABETES', 'Fasting blood sugar', ARRAY['Fasting Blood Sugar','Blood Sugar','BS','سكر صائم','سكر','جلوكوز صائم','Glucose Fasting']::text[]),
  ('RBS', 'RBS', 'السكر العشوائي', 'DIABETES', 'Random blood sugar', ARRAY['Random Blood Sugar','سكر عشوائي','جلوكوز عشوائي']::text[]),
  ('PPBS', 'PPBS', 'السكر بعد الأكل', 'DIABETES', 'Postprandial blood sugar', ARRAY['Postprandial Blood Sugar','سكر بعد الأكل','سكر بعد الوجبة']::text[]),
  ('HbA1c', 'HbA1c', 'السكر التراكمي', 'DIABETES', 'Glycated hemoglobin', ARRAY['A1C','Glycated Hemoglobin','السكر التراكمي','سكر تراكمي','هيموغلوبين سكري']::text[]),
  ('OGTT', 'OGTT', 'اختبار تحمل الجلوكوز', 'DIABETES', 'Oral glucose tolerance test', ARRAY['Glucose Tolerance Test','تحمل السكر']::text[]),
  ('Fasting Insulin', 'F.Insulin', 'الإنسولين الصائم', 'DIABETES', 'Fasting insulin', ARRAY['Insulin Fasting','انسولين صائم']::text[]),
  ('Insulin', 'Insulin', 'الإنسولين', 'DIABETES', 'Insulin', ARRAY['انسولين','إنسولين']::text[]),
  ('C-Peptide', 'C-Peptide', 'سي ببتايد', 'DIABETES', 'C-Peptide', ARRAY['C Peptide','سي بيبتايد']::text[]),
  ('HOMA-IR', 'HOMA-IR', 'مقاومة الإنسولين', 'DIABETES', 'HOMA-IR index', ARRAY['HOMA IR','مقاومة انسولين','مقاومة الإنسولين']::text[]),
  ('Urea', 'Urea', 'اليوريا', 'KIDNEY', 'Blood urea', ARRAY['BUN','Blood Urea','يوريا','وظائف الكلى']::text[]),
  ('Creatinine', 'Cr', 'الكرياتينين', 'KIDNEY', 'Serum creatinine', ARRAY['كرياتينين','كلية','كلى','وظائف الكلى']::text[]),
  ('eGFR', 'eGFR', 'معدل الترشيح الكبيبي', 'KIDNEY', 'Estimated GFR', ARRAY['GFR','Estimated GFR','ترشيح كبيبي']::text[]),
  ('Uric Acid', 'UA', 'حمض اليوريك', 'KIDNEY', 'Uric acid', ARRAY['Urate','يوريك','نقرس']::text[]),
  ('Urine Microalbumin', 'U.MA', 'الألبومين الميكروي بالبول', 'KIDNEY', 'Urine microalbumin', ARRAY['Microalbumin','مايكروألبومين','زلال دقيق']::text[]),
  ('Urine ACR', 'ACR', 'نسبة الألبومين إلى الكرياتينين', 'KIDNEY', 'Albumin/Creatinine ratio', ARRAY['Albumin/Creatinine Ratio','ACR','نسبة الزلال']::text[]),
  ('24 Hour Urine Protein', '24h UP', 'بروتين بول 24 ساعة', 'KIDNEY', '24-hour urine protein', ARRAY['24h Urine Protein','بروتين 24 ساعة']::text[]),
  ('Creatinine Clearance', 'CrCl', 'تصفية الكرياتينين', 'KIDNEY', 'Creatinine clearance', ARRAY['Clearance','تصفية']::text[]),
  ('Sodium', 'Na', 'الصوديوم', 'ELECTROLYTES', 'Sodium', ARRAY['Na','صوديوم']::text[]),
  ('Potassium', 'K', 'البوتاسيوم', 'ELECTROLYTES', 'Potassium', ARRAY['K','بوتاسيوم']::text[]),
  ('Chloride', 'Cl', 'الكلوريد', 'ELECTROLYTES', 'Chloride', ARRAY['Cl','كلور']::text[]),
  ('Calcium', 'Ca', 'الكالسيوم', 'ELECTROLYTES', 'Serum calcium', ARRAY['Ca','كالسيوم']::text[]),
  ('Ionized Calcium', 'iCa', 'الكالسيوم المتأين', 'ELECTROLYTES', 'Ionized calcium', ARRAY['Free Calcium','كالسيوم متأين']::text[]),
  ('Magnesium', 'Mg', 'المغنيسيوم', 'ELECTROLYTES', 'Magnesium', ARRAY['Mg','مغنيسيوم','مغنسيوم']::text[]),
  ('Phosphorus', 'Phos', 'الفوسفور', 'ELECTROLYTES', 'Phosphate', ARRAY['Phosphate','PO4','فوسفور','فوسفات']::text[]),
  ('Zinc', 'Zn', 'الزنك', 'ELECTROLYTES', 'Zinc', ARRAY['Zn','زنك']::text[]),
  ('Copper', 'Cu', 'النحاس', 'ELECTROLYTES', 'Copper', ARRAY['Cu','نحاس']::text[]),
  ('ALT', 'ALT', 'إنزيم الكبد ALT', 'LIVER', 'Alanine aminotransferase', ARRAY['GPT','SGPT','Alanine Aminotransferase','ALT/GPT']::text[]),
  ('AST', 'AST', 'إنزيم الكبد AST', 'LIVER', 'Aspartate aminotransferase', ARRAY['GOT','SGOT','Aspartate Aminotransferase','AST/GOT']::text[]),
  ('ALP', 'ALP', 'الفوسفاتاز القلوي', 'LIVER', 'Alkaline phosphatase', ARRAY['Alkaline Phosphatase','فوسفاتاز']::text[]),
  ('GGT', 'GGT', 'إنزيم GGT', 'LIVER', 'Gamma-glutamyl transferase', ARRAY['Gamma GT','γ-GT','جي جي تي']::text[]),
  ('Total Bilirubin', 'T.Bili', 'البيليروبين الكلي', 'LIVER', 'Total bilirubin', ARRAY['Bilirubin','Total Bili','بيليروبين','صفراء']::text[]),
  ('Direct Bilirubin', 'D.Bili', 'البيليروبين المباشر', 'LIVER', 'Direct bilirubin', ARRAY['Conjugated Bilirubin','بيليروبين مباشر']::text[]),
  ('Indirect Bilirubin', 'I.Bili', 'البيليروبين غير المباشر', 'LIVER', 'Indirect bilirubin', ARRAY['Unconjugated Bilirubin','بيليروبين غير مباشر']::text[]),
  ('Albumin', 'Alb', 'الألبومين', 'LIVER', 'Albumin', ARRAY['Serum Albumin','ألبومين','زلال']::text[]),
  ('Total Protein', 'TP', 'البروتين الكلي', 'LIVER', 'Total protein', ARRAY['Serum Protein','بروتين كلي']::text[]),
  ('Globulin', 'Glob', 'الغلوبولين', 'LIVER', 'Globulin', ARRAY['غلوبولين']::text[]),
  ('A/G Ratio', 'A/G', 'نسبة الألبومين للغلوبولين', 'LIVER', 'Albumin/Globulin ratio', ARRAY['AG Ratio','نسبة A/G']::text[]),
  ('Total Cholesterol', 'TC', 'الكوليسترول الكلي', 'LIPIDS', 'Total cholesterol', ARRAY['Cholesterol','كوليسترول','كوليسترول كلي','Lipid Profile','دهون']::text[]),
  ('Triglycerides', 'TG', 'الدهون الثلاثية', 'LIPIDS', 'Triglycerides', ARRAY['TG','ثلاثي الغليسريد','دهون ثلاثية','Triglyceride']::text[]),
  ('HDL', 'HDL', 'الكوليسترول النافع', 'LIPIDS', 'HDL cholesterol', ARRAY['HDL-C','كوليسترول نافع','HDL Cholesterol']::text[]),
  ('LDL', 'LDL', 'الكوليسترول الضار', 'LIPIDS', 'LDL cholesterol', ARRAY['LDL-C','كوليسترول ضار','LDL Cholesterol']::text[]),
  ('VLDL', 'VLDL', 'كوليسترول VLDL', 'LIPIDS', 'VLDL cholesterol', ARRAY['VLDL-C']::text[]),
  ('Non-HDL Cholesterol', 'Non-HDL', 'كوليسترول غير HDL', 'LIPIDS', 'Non-HDL cholesterol', ARRAY['Non HDL']::text[]),
  ('Apolipoprotein A1', 'ApoA1', 'أبوليبوبروتين A1', 'LIPIDS', 'Apolipoprotein A1', ARRAY['Apo A1','ApoA-I']::text[]),
  ('Apolipoprotein B', 'ApoB', 'أبوليبوبروتين B', 'LIPIDS', 'Apolipoprotein B', ARRAY['Apo B','ApoB-100']::text[]),
  ('Lipoprotein(a)', 'Lp(a)', 'ليبوبورتين أ', 'LIPIDS', 'Lipoprotein(a)', ARRAY['Lp(a)','LPA','Lipoprotein a']::text[]),
  ('TSH', 'TSH', 'الهرمون المحفز للغدة الدرقية', 'THYROID', 'Thyroid stimulating hormone', ARRAY['Thyroid','الغدة','الغدة الدرقية','هرمون الغدة','Thyroid Stimulating Hormone']::text[]),
  ('T3', 'T3', 'هرمون T3', 'THYROID', 'Triiodothyronine', ARRAY['Total T3','Triiodothyronine']::text[]),
  ('T4', 'T4', 'هرمون T4', 'THYROID', 'Thyroxine', ARRAY['Total T4','Thyroxine']::text[]),
  ('Free T3', 'FT3', 'T3 الحر', 'THYROID', 'Free T3', ARRAY['FT3','Free Triiodothyronine','تي3 حر']::text[]),
  ('Free T4', 'FT4', 'T4 الحر', 'THYROID', 'Free T4', ARRAY['FT4','Free Thyroxine','تي4 حر']::text[]),
  ('Anti-TPO', 'Anti-TPO', 'أجسام مضادة لـ TPO', 'THYROID', 'Anti-thyroid peroxidase', ARRAY['TPO Ab','Anti TPO','مضاد TPO']::text[]),
  ('Anti-Thyroglobulin', 'Anti-TG', 'أجسام مضادة للثيروغلوبيولين', 'THYROID', 'Anti-thyroglobulin', ARRAY['Anti-TG','TG Ab','Anti TG']::text[]),
  ('Thyroglobulin', 'Thyroglob', 'الثيروغلوبيولين', 'THYROID', 'Thyroglobulin', ARRAY['TG','ثيروغلوبيولين']::text[]),
  ('TRAb', 'TRAb', 'أجسام مضادة لمستقبلات TSH', 'THYROID', 'TSH receptor antibodies', ARRAY['TSH Receptor Antibody']::text[]),
  ('Serum Iron', 'Iron', 'الحديد في الدم', 'IRON', 'Serum iron', ARRAY['Iron','حديد','Fe']::text[]),
  ('Ferritin', 'Ferritin', 'مخزون الحديد', 'IRON', 'Ferritin', ARRAY['مخزون الحديد','خزين الحديد','حديد مخزون','فيريتين']::text[]),
  ('TIBC', 'TIBC', 'سعة ارتباط الحديد الكلية', 'IRON', 'Total iron binding capacity', ARRAY['Total Iron Binding Capacity']::text[]),
  ('UIBC', 'UIBC', 'سعة ارتباط الحديد غير المشبعة', 'IRON', 'Unsaturated iron binding capacity', ARRAY['Unsaturated Iron Binding Capacity']::text[]),
  ('Transferrin', 'Transferrin', 'الترانسفيرين', 'IRON', 'Transferrin', ARRAY['ترانسفيرين']::text[]),
  ('Transferrin Saturation', 'TSAT', 'تشبع الترانسفيرين', 'IRON', 'Transferrin saturation', ARRAY['TSAT','% Saturation','تشبع الحديد']::text[]),
  ('Vitamin B12', 'B12', 'فيتامين ب12', 'VITAMINS', 'Vitamin B12', ARRAY['B12','Cobalamin','فيتامين B12','فيتامين بي 12']::text[]),
  ('Folate', 'Folate', 'حمض الفوليك', 'VITAMINS', 'Folate / Vitamin B9', ARRAY['Folic Acid','Vitamin B9','B9','فولات','فوليك']::text[]),
  ('Vitamin D', 'Vit D', 'فيتامين د', 'VITAMINS', '25-OH Vitamin D', ARRAY['Vit D','D3','25-OH Vitamin D','25 OH D','فيتامين دي','فيتامين دال','Vitamin D3']::text[]),
  ('Vitamin A', 'Vit A', 'فيتامين أ', 'VITAMINS', 'Vitamin A', ARRAY['Retinol','فيتامين A']::text[]),
  ('Vitamin E', 'Vit E', 'فيتامين هـ', 'VITAMINS', 'Vitamin E', ARRAY['Tocopherol','فيتامين E']::text[]),
  ('CRP', 'CRP', 'بروتين سي التفاعلي', 'INFLAMMATION', 'C-Reactive Protein', ARRAY['C-Reactive Protein','سي آر بي','التهاب']::text[]),
  ('hs-CRP', 'hs-CRP', 'بروتين سي عالي الحساسية', 'INFLAMMATION', 'High-sensitivity CRP', ARRAY['High Sensitivity CRP','hsCRP']::text[]),
  ('Procalcitonin', 'PCT', 'البروكالسيتونين', 'INFLAMMATION', 'Procalcitonin', ARRAY['PCT','بروكالسيتونين']::text[]),
  ('RF', 'RF', 'عامل الروماتويد', 'RHEUMATOLOGY', 'Rheumatoid factor', ARRAY['Rheumatoid Factor','روماتويد']::text[]),
  ('Anti-CCP', 'Anti-CCP', 'مضاد CCP', 'RHEUMATOLOGY', 'Anti-CCP antibodies', ARRAY['CCP','Anti CCP','ACPA']::text[]),
  ('ANA', 'ANA', 'الأجسام المضادة للنواة', 'RHEUMATOLOGY', 'Antinuclear antibodies', ARRAY['Antinuclear Antibody','ANA Screen']::text[]),
  ('Anti-dsDNA', 'dsDNA', 'مضاد الحمض النووي', 'RHEUMATOLOGY', 'Anti-double stranded DNA', ARRAY['Anti dsDNA','Anti-DNA']::text[]),
  ('C3', 'C3', 'المتممة C3', 'RHEUMATOLOGY', 'Complement C3', ARRAY['Complement C3']::text[]),
  ('C4', 'C4', 'المتممة C4', 'RHEUMATOLOGY', 'Complement C4', ARRAY['Complement C4']::text[]),
  ('ASO', 'ASO', 'مضاد الستربتوليزين', 'RHEUMATOLOGY', 'Antistreptolysin O', ARRAY['ASOT','Antistreptolysin O','آسو']::text[]),
  ('Troponin I', 'TnI', 'تروبونين I', 'CARDIAC', 'Troponin I', ARRAY['cTnI','Troponin-I','تروبونين']::text[]),
  ('Troponin T', 'TnT', 'تروبونين T', 'CARDIAC', 'Troponin T', ARRAY['cTnT','Troponin-T']::text[]),
  ('High-Sensitivity Troponin', 'hs-Tn', 'تروبونين عالي الحساسية', 'CARDIAC', 'High-sensitivity troponin', ARRAY['hsTroponin','hs-cTn']::text[]),
  ('CK', 'CK', 'كرياتين كاينيز', 'CARDIAC', 'Creatine kinase', ARRAY['CPK','Creatine Kinase']::text[]),
  ('CK-MB', 'CK-MB', 'كرياتين كاينيز MB', 'CARDIAC', 'CK-MB isoenzyme', ARRAY['CKMB','CPK-MB']::text[]),
  ('LDH', 'LDH', 'نازعة لاكتات', 'CARDIAC', 'Lactate dehydrogenase', ARRAY['Lactate Dehydrogenase']::text[]),
  ('BNP', 'BNP', 'بيتا ناتريوتيك', 'CARDIAC', 'B-type natriuretic peptide', ARRAY['B-type Natriuretic Peptide']::text[]),
  ('NT-proBNP', 'NT-proBNP', 'إن تي برو بي إن بي', 'CARDIAC', 'N-terminal pro-BNP', ARRAY['NTproBNP']::text[]),
  ('Myoglobin', 'Myo', 'الميوغلوبين', 'CARDIAC', 'Myoglobin', ARRAY['ميوغلوبين']::text[]),
  ('Amylase', 'AMY', 'الأميليز', 'PANCREAS', 'Amylase', ARRAY['Serum Amylase','أميليز']::text[]),
  ('Lipase', 'LIP', 'الليباز', 'PANCREAS', 'Lipase', ARRAY['Serum Lipase','ليباز']::text[]),
  ('Testosterone Total', 'Testo', 'التستوستيرون الكلي', 'HORMONES', 'Total testosterone', ARRAY['Testosterone','Total Testosterone','تستوستيرون']::text[]),
  ('Free Testosterone', 'Free Testo', 'التستوستيرون الحر', 'HORMONES', 'Free testosterone', ARRAY['Free Testo','تستوستيرون حر']::text[]),
  ('Estradiol', 'E2', 'الإستراديول', 'HORMONES', 'Estradiol', ARRAY['E2','Oestradiol','استراديول']::text[]),
  ('Progesterone', 'Prog', 'البروجستيرون', 'HORMONES', 'Progesterone', ARRAY['بروجستيرون']::text[]),
  ('Prolactin', 'PRL', 'البرولاكتين', 'HORMONES', 'Prolactin', ARRAY['PRL','برولاكتين']::text[]),
  ('FSH', 'FSH', 'الهرمون المنبه للجريب', 'HORMONES', 'Follicle stimulating hormone', ARRAY['Follicle Stimulating Hormone']::text[]),
  ('LH', 'LH', 'الهرمون المنبه للجسم الأصفر', 'HORMONES', 'Luteinizing hormone', ARRAY['Luteinizing Hormone']::text[]),
  ('Cortisol', 'Cortisol', 'الكورتيزول', 'HORMONES', 'Cortisol', ARRAY['كورتيزول']::text[]),
  ('ACTH', 'ACTH', 'الهرمون الموجه لقشرة الكظر', 'HORMONES', 'ACTH', ARRAY['Adrenocorticotropic Hormone']::text[]),
  ('DHEA-S', 'DHEA-S', 'ديهيدرو إيبي أندروستيرون', 'HORMONES', 'DHEA-S', ARRAY['DHEAS','DHEA Sulfate']::text[]),
  ('SHBG', 'SHBG', 'الغلوبيولين الرابط للهرمونات الجنسية', 'HORMONES', 'Sex hormone binding globulin', ARRAY['Sex Hormone Binding Globulin']::text[]),
  ('Growth Hormone', 'GH', 'هرمون النمو', 'HORMONES', 'Growth hormone', ARRAY['GH','HGH','هرمون النمو']::text[]),
  ('IGF-1', 'IGF-1', 'عامل النمو الشبيه بالإنسولين', 'HORMONES', 'IGF-1', ARRAY['IGF1','Somatomedin C']::text[]),
  ('PTH', 'PTH', 'هرمون جارات الدرق', 'HORMONES', 'Parathyroid hormone', ARRAY['Parathyroid Hormone','باراثورمون']::text[]),
  ('Beta-hCG Quantitative', 'β-hCG', 'هرمون الحمل الكمي', 'FERTILITY', 'Quantitative beta-hCG', ARRAY['Beta hCG','hCG Quantitative','بيتا HCG','حمل كمي']::text[]),
  ('Pregnancy Test', 'hCG Qual', 'اختبار الحمل', 'FERTILITY', 'Qualitative hCG', ARRAY['hCG Qualitative','اختبار حمل','حمل']::text[]),
  ('AMH', 'AMH', 'مخزون المبيض', 'FERTILITY', 'Anti-Mullerian hormone', ARRAY['Anti-Mullerian Hormone','مخزون مبايض']::text[]),
  ('Semen Analysis', 'Semen', 'تحليل السائل المنوي', 'FERTILITY', 'Semen analysis', ARRAY['Sperm Analysis','سائل منوي']::text[]),
  ('PSA Total', 'PSA', 'مستضد البروستات الكلي', 'PROSTATE', 'Total PSA', ARRAY['PSA','Prostate Specific Antigen','بروستات']::text[]),
  ('PSA Free', 'fPSA', 'مستضد البروستات الحر', 'PROSTATE', 'Free PSA', ARRAY['Free PSA']::text[]),
  ('Free/Total PSA Ratio', 'f/t PSA', 'نسبة PSA الحر للكلي', 'PROSTATE', 'Free/Total PSA ratio', ARRAY['PSA Ratio','نسبة PSA']::text[]),
  ('General Urine Examination', 'GUE', 'تحليل الإدرار العام', 'URINE', 'General urine examination', ARRAY['Urinalysis','UE','تحليل بول','إدرار','بول عام']::text[]),
  ('Urine Culture', 'U.Culture', 'زرع الإدرار', 'URINE', 'Urine culture', ARRAY['Culture Urine','زرع بول']::text[]),
  ('Urine Protein', 'U.Prot', 'بروتين البول', 'URINE', 'Urine protein', ARRAY['Proteinuria','بروتين بول']::text[]),
  ('Urine Glucose', 'U.Glu', 'سكر البول', 'URINE', 'Urine glucose', ARRAY['Glycosuria','سكر بول']::text[]),
  ('Urine Ketones', 'U.Ket', 'كيتون البول', 'URINE', 'Urine ketones', ARRAY['Ketonuria','كيتونات']::text[]),
  ('General Stool Examination', 'GSE', 'تحليل البراز العام', 'STOOL', 'General stool examination', ARRAY['Stool Analysis','تحليل براز','براز']::text[]),
  ('Stool Culture', 'S.Culture', 'زرع البراز', 'STOOL', 'Stool culture', ARRAY['Culture Stool','زرع براز']::text[]),
  ('Occult Blood', 'FOBT', 'الدم الخفي في البراز', 'STOOL', 'Fecal occult blood', ARRAY['FOBT','Fecal Occult Blood','دم خفي']::text[]),
  ('H. pylori Stool Antigen', 'H.pylori Ag', 'مستضد جرثومة المعدة بالبراز', 'STOOL', 'H. pylori stool antigen', ARRAY['Helicobacter Pylori Antigen','جرثومة المعدة','هليكوباكتر']::text[]),
  ('Calprotectin', 'Calprotectin', 'الكالبروتكتين', 'STOOL', 'Fecal calprotectin', ARRAY['Fecal Calprotectin']::text[]),
  ('Ova & Parasites', 'O&P', 'الديدان والطفيليات', 'STOOL', 'Ova and parasites', ARRAY['Parasites','طفيليات','ديدان']::text[]),
  ('H. pylori Antibody', 'H.pylori Ab', 'أجسام مضادة لجرثومة المعدة', 'INFECTIOUS', 'H. pylori antibody', ARRAY['H.pylori Ab','Helicobacter Antibody']::text[]),
  ('H. pylori IgG', 'H.pylori IgG', 'IgG لجرثومة المعدة', 'INFECTIOUS', 'H. pylori IgG', ARRAY['Helicobacter IgG']::text[]),
  ('H. pylori Breath Test', 'UBT', 'اختبار النفس لجرثومة المعدة', 'INFECTIOUS', 'Urea breath test', ARRAY['Urea Breath Test','اختبار نفس']::text[]),
  ('HBsAg', 'HBsAg', 'مستضد التهاب الكبد B', 'HEPATITIS', 'Hepatitis B surface antigen', ARRAY['Hepatitis B Surface Antigen','التهاب الكبد B']::text[]),
  ('Anti-HBs', 'Anti-HBs', 'مضاد HBs', 'HEPATITIS', 'Hepatitis B surface antibody', ARRAY['HBsAb','Anti HBs']::text[]),
  ('Anti-HBc Total', 'Anti-HBc', 'مضاد HBc الكلي', 'HEPATITIS', 'Total anti-HBc', ARRAY['HBcAb Total','Anti HBc']::text[]),
  ('Anti-HBc IgM', 'HBc IgM', 'مضاد HBc من نوع IgM', 'HEPATITIS', 'Anti-HBc IgM', ARRAY['HBcIgM']::text[]),
  ('HBeAg', 'HBeAg', 'مستضد HBe', 'HEPATITIS', 'Hepatitis B e antigen', ARRAY['HBe Antigen']::text[]),
  ('Anti-HBe', 'Anti-HBe', 'مضاد HBe', 'HEPATITIS', 'Hepatitis B e antibody', ARRAY['HBeAb']::text[]),
  ('HCV Ab', 'HCV Ab', 'أجسام مضادة لالتهاب الكبد C', 'HEPATITIS', 'Hepatitis C antibody', ARRAY['Anti-HCV','HCV','التهاب الكبد C']::text[]),
  ('HIV Ag/Ab', 'HIV', 'فحص فيروس نقص المناعة', 'HEPATITIS', 'HIV antigen/antibody', ARRAY['HIV','HIV Combo','ايدز']::text[]),
  ('HAV IgM', 'HAV IgM', 'التهاب الكبد A IgM', 'HEPATITIS', 'Hepatitis A IgM', ARRAY['Hepatitis A IgM']::text[]),
  ('HAV IgG', 'HAV IgG', 'التهاب الكبد A IgG', 'HEPATITIS', 'Hepatitis A IgG', ARRAY['Hepatitis A IgG']::text[]),
  ('VDRL', 'VDRL', 'فحص الزهري VDRL', 'SEROLOGY', 'VDRL syphilis test', ARRAY['Syphilis VDRL']::text[]),
  ('RPR', 'RPR', 'فحص الزهري RPR', 'SEROLOGY', 'Rapid plasma reagin', ARRAY['Syphilis RPR']::text[]),
  ('TPHA', 'TPHA', 'تأكيد الزهري TPHA', 'SEROLOGY', 'TPHA', ARRAY['Treponema Pallidum']::text[]),
  ('Brucella', 'Brucella', 'البروسيلا', 'SEROLOGY', 'Brucella serology', ARRAY['بروسيلا','مالطا']::text[]),
  ('Widal', 'Widal', 'ويدال', 'SEROLOGY', 'Widal test', ARRAY['Typhoid','تيفوئيد','ويدال']::text[]),
  ('Toxoplasma IgG', 'Toxo IgG', 'توكسوبلازما IgG', 'SEROLOGY', 'Toxoplasma IgG', ARRAY['Toxoplasma']::text[]),
  ('Toxoplasma IgM', 'Toxo IgM', 'توكسوبلازما IgM', 'SEROLOGY', 'Toxoplasma IgM', ARRAY['Toxo IgM']::text[]),
  ('CMV IgG', 'CMV IgG', 'فيروس CMV IgG', 'SEROLOGY', 'CMV IgG', ARRAY['Cytomegalovirus IgG']::text[]),
  ('CMV IgM', 'CMV IgM', 'فيروس CMV IgM', 'SEROLOGY', 'CMV IgM', ARRAY['Cytomegalovirus IgM']::text[]),
  ('Rubella IgG', 'Rubella IgG', 'الحصبة الألمانية IgG', 'SEROLOGY', 'Rubella IgG', ARRAY['حصبة ألمانية']::text[]),
  ('Rubella IgM', 'Rubella IgM', 'الحصبة الألمانية IgM', 'SEROLOGY', 'Rubella IgM', ARRAY['Rubella']::text[]),
  ('EBV', 'EBV', 'فيروس إبشتاين بار', 'SEROLOGY', 'Epstein-Barr virus serology', ARRAY['Epstein-Barr','EBV VCA']::text[]),
  ('Blood Culture', 'B.Culture', 'زرع الدم', 'CULTURE', 'Blood culture', ARRAY['Culture Blood','زرع دم']::text[]),
  ('Sputum Culture', 'Sp.Culture', 'زرع القشع', 'CULTURE', 'Sputum culture', ARRAY['Culture Sputum']::text[]),
  ('Throat Swab Culture', 'Throat', 'زرع مسحة الحلق', 'CULTURE', 'Throat swab culture', ARRAY['Throat Culture','حلق']::text[]),
  ('Wound Culture', 'Wound', 'زرع الجرح', 'CULTURE', 'Wound culture', ARRAY['Culture Wound']::text[]),
  ('High Vaginal Swab Culture', 'HVS', 'زرع المسحة المهبلية', 'CULTURE', 'High vaginal swab culture', ARRAY['HVS Culture','مسحة مهبلية']::text[]),
  ('Lactate', 'Lactate', 'اللاكتات', 'OTHER', 'Lactate', ARRAY['Lactic Acid','لاكتات']::text[]),
  ('Ammonia', 'NH3', 'الأمونيا', 'OTHER', 'Ammonia', ARRAY['NH3','امونيا']::text[]),
  ('Ceruloplasmin', 'Cp', 'السيرولوبلازمين', 'OTHER', 'Ceruloplasmin', ARRAY['سيرولوبلازمين']::text[])
)
update public.analyses a
set
  short_name = coalesce(nullif(a.short_name, ''), s.short_name),
  name_ar = case when coalesce(a.name_ar, '') = '' then s.name_ar else a.name_ar end,
  category = case when coalesce(a.category, '') = '' then s.category else a.category end,
  description = case when coalesce(a.description, '') in ('', s.description) then s.description else a.description end,
  aliases = case when coalesce(cardinality(a.aliases), 0) = 0 then s.aliases else a.aliases end
from seed s
where lower(trim(a.name)) = lower(trim(s.name));

-- إثراء Blood Sugar / Lipid Profile الحاليين بـ aliases بدون حذف
update public.analyses set
  name_ar = coalesce(nullif(name_ar, ''), 'السكر'),
  category = coalesce(nullif(category, ''), 'DIABETES'),
  aliases = case when cardinality(aliases) = 0 then array['Blood Sugar','BS','FBS','RBS','سكر','جلوكوز']::text[] else aliases end
where lower(trim(name)) = 'blood sugar';
update public.analyses set
  name_ar = coalesce(nullif(name_ar, ''), 'دهون الدم'),
  category = coalesce(nullif(category, ''), 'LIPIDS'),
  aliases = case when cardinality(aliases) = 0 then array['Lipid Profile','Lipids','دهون','كوليسترول']::text[] else aliases end
where lower(trim(name)) = 'lipid profile';

-- 5) تحديث search_text للبحث
update public.analyses
set search_text = lower(trim(concat_ws(' ',
  name,
  coalesce(short_name, ''),
  coalesce(name_ar, ''),
  coalesce(description, ''),
  array_to_string(aliases, ' ')
)));
-- فهرس بحث نصي بسيط (البحث الأساسي يتم أيضًا من التطبيق)
create index if not exists analyses_search_text_idx on public.analyses (search_text);
create index if not exists analyses_category_idx on public.analyses (category);
create index if not exists analyses_is_active_name_idx on public.analyses (is_active, name);

-- 6) Seed القوالب
with seed(name, description, display_order) as ( values
  ('باقة الفحص الأساسي', 'فحوصات أولية شائعة', 1),
  ('باقة الفحص الشامل', 'تقييم أوسع للصحة العامة', 2),
  ('باقة الفحص الدوري', 'متابعة دورية روتينية', 3),
  ('باقة وظائف الجسم', 'وظائف الأعضاء الأساسية', 4),
  ('باقة الصحة العامة', 'صحة عامة للبالغين', 5),
  ('باقة تساقط الشعر', 'فحوصات مرتبطة بتساقط الشعر', 6),
  ('باقة الشعر والبشرة والأظافر', 'تغذية ومكملات مرتبطة بالشعر والبشرة', 7),
  ('باقة التعب والإرهاق', 'أسباب شائعة للتعب', 8),
  ('باقة الرياضيين', 'فحوصات شائعة للرياضيين', 9),
  ('باقة المفاصل', 'تقييم آلام المفاصل', 10),
  ('باقة الروماتيزم', 'مؤشرات روماتيزمية شائعة', 11),
  ('باقة هشاشة العظام', 'معادن وعوامل مرتبطة بالعظم', 12),
  ('باقة الفيتامينات والمعادن', 'فيتامينات ومعادن أساسية', 13),
  ('باقة فقر الدم', 'تقييم فقر الدم', 14),
  ('باقة نقص الحديد', 'مخزون الحديد ومؤشراته', 15),
  ('باقة السكري', 'تشخيص ومتابعة السكري', 16),
  ('باقة متابعة السكري', 'متابعة دورية لمريض السكري', 17),
  ('باقة مقاومة الإنسولين', 'مؤشرات مقاومة الإنسولين', 18),
  ('باقة الأمراض المزمنة الدورية', 'متابعة أمراض مزمنة شائعة', 19),
  ('باقة وظائف الكلى', 'تقييم وظائف الكلى', 20),
  ('باقة وظائف الكبد', 'إنزيمات ووظائف الكبد', 21),
  ('باقة الدهون والكوليسترول', 'دهون الدم', 22),
  ('باقة القلب', 'مؤشرات قلبية واستقلابية', 23),
  ('باقة الغدة الدرقية', 'تقييم الغدة الدرقية', 24),
  ('باقة صحة المرأة', 'فحوصات عامة للنساء', 25),
  ('باقة صحة الرجل', 'فحوصات عامة للرجال', 26),
  ('باقة الهرمونات النسائية', 'محور هرموني نسائي', 27),
  ('باقة الهرمونات الرجالية', 'محور هرموني رجالي', 28),
  ('باقة الخصوبة للنساء', 'تقييم خصوبة النساء', 29),
  ('باقة الخصوبة للرجال', 'تقييم خصوبة الرجال', 30),
  ('باقة ما قبل الحمل', 'فحوصات ما قبل الحمل', 31),
  ('باقة ما قبل الزواج', 'فحوصات ما قبل الزواج الشائعة', 32),
  ('باقة الحمل', 'فحوصات حمل شائعة', 33),
  ('باقة كبار السن', 'متابعة كبار السن', 34),
  ('باقة الأطفال', 'فحوصات شائعة للأطفال', 35),
  ('باقة السمنة', 'تقييم مرافق للسمنة', 36),
  ('باقة المناعة', 'مؤشرات مناعية أساسية', 37),
  ('باقة الالتهابات', 'مؤشرات التهاب', 38),
  ('باقة التخثر', 'فحوصات التخثر', 39),
  ('باقة الفيروسات', 'فحوصات فيروسية شائعة', 40),
  ('باقة صحة الجهاز الهضمي', 'فحوصات هضمية شائعة', 41)
)
insert into public.package_templates (name, description, display_order, is_active)
select s.name, s.description, s.display_order, true
from seed s
where not exists (
  select 1 from public.package_templates t where lower(trim(t.name)) = lower(trim(s.name))
);

-- 7) ربط القوالب بالتحاليل عبر الاسم (بدون تكرار)
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الأساسي'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الأساسي'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Creatinine'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الأساسي'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Urea'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الأساسي'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ALT'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الأساسي'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('AST'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الأساسي'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Total Cholesterol'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الأساسي'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Triglycerides'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الأساسي'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الأساسي'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 9
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('General Urine Examination'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الأساسي'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ESR'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HbA1c'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Creatinine'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Urea'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Uric Acid'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ALT'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('AST'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 9
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ALP'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 10
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Total Bilirubin'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 11
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Total Cholesterol'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 12
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Triglycerides'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 13
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HDL'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 14
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('LDL'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 15
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 16
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin D'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 17
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Ferritin'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 18
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('General Urine Examination'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الشامل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الدوري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الدوري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HbA1c'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الدوري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Creatinine'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الدوري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ALT'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الدوري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('AST'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الدوري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Total Cholesterol'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الدوري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Triglycerides'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الدوري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الدوري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 9
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin D'))
where lower(trim(t.name)) = lower(trim('باقة الفحص الدوري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الجسم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الجسم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Creatinine'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الجسم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Urea'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الجسم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('eGFR'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الجسم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ALT'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الجسم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('AST'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الجسم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ALP'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الجسم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('GGT'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الجسم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 9
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Total Bilirubin'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الجسم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 10
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Albumin'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الجسم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 11
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Sodium'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الجسم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 12
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Potassium'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الجسم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة الصحة العامة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة الصحة العامة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HbA1c'))
where lower(trim(t.name)) = lower(trim('باقة الصحة العامة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Creatinine'))
where lower(trim(t.name)) = lower(trim('باقة الصحة العامة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ALT'))
where lower(trim(t.name)) = lower(trim('باقة الصحة العامة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('AST'))
where lower(trim(t.name)) = lower(trim('باقة الصحة العامة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Total Cholesterol'))
where lower(trim(t.name)) = lower(trim('باقة الصحة العامة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HDL'))
where lower(trim(t.name)) = lower(trim('باقة الصحة العامة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('LDL'))
where lower(trim(t.name)) = lower(trim('باقة الصحة العامة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 9
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Triglycerides'))
where lower(trim(t.name)) = lower(trim('باقة الصحة العامة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 10
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة الصحة العامة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 11
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin D'))
where lower(trim(t.name)) = lower(trim('باقة الصحة العامة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 12
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin B12'))
where lower(trim(t.name)) = lower(trim('باقة الصحة العامة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة تساقط الشعر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Ferritin'))
where lower(trim(t.name)) = lower(trim('باقة تساقط الشعر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Serum Iron'))
where lower(trim(t.name)) = lower(trim('باقة تساقط الشعر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin D'))
where lower(trim(t.name)) = lower(trim('باقة تساقط الشعر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin B12'))
where lower(trim(t.name)) = lower(trim('باقة تساقط الشعر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة تساقط الشعر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Free T4'))
where lower(trim(t.name)) = lower(trim('باقة تساقط الشعر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Zinc'))
where lower(trim(t.name)) = lower(trim('باقة تساقط الشعر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Magnesium'))
where lower(trim(t.name)) = lower(trim('باقة تساقط الشعر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة الشعر والبشرة والأظافر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Ferritin'))
where lower(trim(t.name)) = lower(trim('باقة الشعر والبشرة والأظافر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Serum Iron'))
where lower(trim(t.name)) = lower(trim('باقة الشعر والبشرة والأظافر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Zinc'))
where lower(trim(t.name)) = lower(trim('باقة الشعر والبشرة والأظافر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin D'))
where lower(trim(t.name)) = lower(trim('باقة الشعر والبشرة والأظافر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin B12'))
where lower(trim(t.name)) = lower(trim('باقة الشعر والبشرة والأظافر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Folate'))
where lower(trim(t.name)) = lower(trim('باقة الشعر والبشرة والأظافر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة الشعر والبشرة والأظافر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة التعب والإرهاق'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Ferritin'))
where lower(trim(t.name)) = lower(trim('باقة التعب والإرهاق'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin D'))
where lower(trim(t.name)) = lower(trim('باقة التعب والإرهاق'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin B12'))
where lower(trim(t.name)) = lower(trim('باقة التعب والإرهاق'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة التعب والإرهاق'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة التعب والإرهاق'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Free T4'))
where lower(trim(t.name)) = lower(trim('باقة التعب والإرهاق'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Creatinine'))
where lower(trim(t.name)) = lower(trim('باقة التعب والإرهاق'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Urea'))
where lower(trim(t.name)) = lower(trim('باقة التعب والإرهاق'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 9
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ALT'))
where lower(trim(t.name)) = lower(trim('باقة التعب والإرهاق'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 10
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('AST'))
where lower(trim(t.name)) = lower(trim('باقة التعب والإرهاق'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 11
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Sodium'))
where lower(trim(t.name)) = lower(trim('باقة التعب والإرهاق'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 12
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Potassium'))
where lower(trim(t.name)) = lower(trim('باقة التعب والإرهاق'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة الرياضيين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة الرياضيين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Creatinine'))
where lower(trim(t.name)) = lower(trim('باقة الرياضيين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Urea'))
where lower(trim(t.name)) = lower(trim('باقة الرياضيين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ALT'))
where lower(trim(t.name)) = lower(trim('باقة الرياضيين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('AST'))
where lower(trim(t.name)) = lower(trim('باقة الرياضيين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CK'))
where lower(trim(t.name)) = lower(trim('باقة الرياضيين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Ferritin'))
where lower(trim(t.name)) = lower(trim('باقة الرياضيين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin D'))
where lower(trim(t.name)) = lower(trim('باقة الرياضيين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 9
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin B12'))
where lower(trim(t.name)) = lower(trim('باقة الرياضيين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 10
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Calcium'))
where lower(trim(t.name)) = lower(trim('باقة الرياضيين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 11
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Magnesium'))
where lower(trim(t.name)) = lower(trim('باقة الرياضيين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 12
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Sodium'))
where lower(trim(t.name)) = lower(trim('باقة الرياضيين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 13
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Potassium'))
where lower(trim(t.name)) = lower(trim('باقة الرياضيين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 14
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة الرياضيين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 15
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Testosterone Total'))
where lower(trim(t.name)) = lower(trim('باقة الرياضيين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة المفاصل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ESR'))
where lower(trim(t.name)) = lower(trim('باقة المفاصل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CRP'))
where lower(trim(t.name)) = lower(trim('باقة المفاصل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('RF'))
where lower(trim(t.name)) = lower(trim('باقة المفاصل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Anti-CCP'))
where lower(trim(t.name)) = lower(trim('باقة المفاصل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Uric Acid'))
where lower(trim(t.name)) = lower(trim('باقة المفاصل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin D'))
where lower(trim(t.name)) = lower(trim('باقة المفاصل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Calcium'))
where lower(trim(t.name)) = lower(trim('باقة المفاصل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة الروماتيزم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ESR'))
where lower(trim(t.name)) = lower(trim('باقة الروماتيزم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CRP'))
where lower(trim(t.name)) = lower(trim('باقة الروماتيزم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('RF'))
where lower(trim(t.name)) = lower(trim('باقة الروماتيزم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Anti-CCP'))
where lower(trim(t.name)) = lower(trim('باقة الروماتيزم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ANA'))
where lower(trim(t.name)) = lower(trim('باقة الروماتيزم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ASO'))
where lower(trim(t.name)) = lower(trim('باقة الروماتيزم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Uric Acid'))
where lower(trim(t.name)) = lower(trim('باقة الروماتيزم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Calcium'))
where lower(trim(t.name)) = lower(trim('باقة هشاشة العظام'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Phosphorus'))
where lower(trim(t.name)) = lower(trim('باقة هشاشة العظام'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin D'))
where lower(trim(t.name)) = lower(trim('باقة هشاشة العظام'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('PTH'))
where lower(trim(t.name)) = lower(trim('باقة هشاشة العظام'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ALP'))
where lower(trim(t.name)) = lower(trim('باقة هشاشة العظام'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Magnesium'))
where lower(trim(t.name)) = lower(trim('باقة هشاشة العظام'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin D'))
where lower(trim(t.name)) = lower(trim('باقة الفيتامينات والمعادن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin B12'))
where lower(trim(t.name)) = lower(trim('باقة الفيتامينات والمعادن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Folate'))
where lower(trim(t.name)) = lower(trim('باقة الفيتامينات والمعادن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Serum Iron'))
where lower(trim(t.name)) = lower(trim('باقة الفيتامينات والمعادن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Ferritin'))
where lower(trim(t.name)) = lower(trim('باقة الفيتامينات والمعادن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Zinc'))
where lower(trim(t.name)) = lower(trim('باقة الفيتامينات والمعادن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Magnesium'))
where lower(trim(t.name)) = lower(trim('باقة الفيتامينات والمعادن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Calcium'))
where lower(trim(t.name)) = lower(trim('باقة الفيتامينات والمعادن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Phosphorus'))
where lower(trim(t.name)) = lower(trim('باقة الفيتامينات والمعادن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة فقر الدم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Ferritin'))
where lower(trim(t.name)) = lower(trim('باقة فقر الدم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Serum Iron'))
where lower(trim(t.name)) = lower(trim('باقة فقر الدم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TIBC'))
where lower(trim(t.name)) = lower(trim('باقة فقر الدم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Transferrin Saturation'))
where lower(trim(t.name)) = lower(trim('باقة فقر الدم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin B12'))
where lower(trim(t.name)) = lower(trim('باقة فقر الدم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Folate'))
where lower(trim(t.name)) = lower(trim('باقة فقر الدم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Reticulocyte Count'))
where lower(trim(t.name)) = lower(trim('باقة فقر الدم'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة نقص الحديد'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Ferritin'))
where lower(trim(t.name)) = lower(trim('باقة نقص الحديد'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Serum Iron'))
where lower(trim(t.name)) = lower(trim('باقة نقص الحديد'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TIBC'))
where lower(trim(t.name)) = lower(trim('باقة نقص الحديد'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Transferrin'))
where lower(trim(t.name)) = lower(trim('باقة نقص الحديد'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Transferrin Saturation'))
where lower(trim(t.name)) = lower(trim('باقة نقص الحديد'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('PPBS'))
where lower(trim(t.name)) = lower(trim('باقة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HbA1c'))
where lower(trim(t.name)) = lower(trim('باقة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Creatinine'))
where lower(trim(t.name)) = lower(trim('باقة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('eGFR'))
where lower(trim(t.name)) = lower(trim('باقة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Total Cholesterol'))
where lower(trim(t.name)) = lower(trim('باقة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Triglycerides'))
where lower(trim(t.name)) = lower(trim('باقة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HDL'))
where lower(trim(t.name)) = lower(trim('باقة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('LDL'))
where lower(trim(t.name)) = lower(trim('باقة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 9
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('General Urine Examination'))
where lower(trim(t.name)) = lower(trim('باقة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 10
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Urine Microalbumin'))
where lower(trim(t.name)) = lower(trim('باقة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 11
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Urine ACR'))
where lower(trim(t.name)) = lower(trim('باقة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة متابعة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HbA1c'))
where lower(trim(t.name)) = lower(trim('باقة متابعة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Creatinine'))
where lower(trim(t.name)) = lower(trim('باقة متابعة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('eGFR'))
where lower(trim(t.name)) = lower(trim('باقة متابعة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Urine ACR'))
where lower(trim(t.name)) = lower(trim('باقة متابعة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Total Cholesterol'))
where lower(trim(t.name)) = lower(trim('باقة متابعة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('LDL'))
where lower(trim(t.name)) = lower(trim('باقة متابعة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Triglycerides'))
where lower(trim(t.name)) = lower(trim('باقة متابعة السكري'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة مقاومة الإنسولين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Fasting Insulin'))
where lower(trim(t.name)) = lower(trim('باقة مقاومة الإنسولين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HbA1c'))
where lower(trim(t.name)) = lower(trim('باقة مقاومة الإنسولين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HOMA-IR'))
where lower(trim(t.name)) = lower(trim('باقة مقاومة الإنسولين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Total Cholesterol'))
where lower(trim(t.name)) = lower(trim('باقة مقاومة الإنسولين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Triglycerides'))
where lower(trim(t.name)) = lower(trim('باقة مقاومة الإنسولين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HDL'))
where lower(trim(t.name)) = lower(trim('باقة مقاومة الإنسولين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('LDL'))
where lower(trim(t.name)) = lower(trim('باقة مقاومة الإنسولين'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة الأمراض المزمنة الدورية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة الأمراض المزمنة الدورية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HbA1c'))
where lower(trim(t.name)) = lower(trim('باقة الأمراض المزمنة الدورية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Creatinine'))
where lower(trim(t.name)) = lower(trim('باقة الأمراض المزمنة الدورية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('eGFR'))
where lower(trim(t.name)) = lower(trim('باقة الأمراض المزمنة الدورية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ALT'))
where lower(trim(t.name)) = lower(trim('باقة الأمراض المزمنة الدورية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('AST'))
where lower(trim(t.name)) = lower(trim('باقة الأمراض المزمنة الدورية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Total Cholesterol'))
where lower(trim(t.name)) = lower(trim('باقة الأمراض المزمنة الدورية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('LDL'))
where lower(trim(t.name)) = lower(trim('باقة الأمراض المزمنة الدورية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 9
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Triglycerides'))
where lower(trim(t.name)) = lower(trim('باقة الأمراض المزمنة الدورية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 10
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة الأمراض المزمنة الدورية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 11
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('General Urine Examination'))
where lower(trim(t.name)) = lower(trim('باقة الأمراض المزمنة الدورية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Urea'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الكلى'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Creatinine'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الكلى'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('eGFR'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الكلى'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Uric Acid'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الكلى'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Sodium'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الكلى'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Potassium'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الكلى'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('General Urine Examination'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الكلى'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Urine Microalbumin'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الكلى'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Urine ACR'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الكلى'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ALT'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الكبد'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('AST'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الكبد'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ALP'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الكبد'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('GGT'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الكبد'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Total Bilirubin'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الكبد'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Direct Bilirubin'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الكبد'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Albumin'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الكبد'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Total Protein'))
where lower(trim(t.name)) = lower(trim('باقة وظائف الكبد'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Total Cholesterol'))
where lower(trim(t.name)) = lower(trim('باقة الدهون والكوليسترول'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Triglycerides'))
where lower(trim(t.name)) = lower(trim('باقة الدهون والكوليسترول'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HDL'))
where lower(trim(t.name)) = lower(trim('باقة الدهون والكوليسترول'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('LDL'))
where lower(trim(t.name)) = lower(trim('باقة الدهون والكوليسترول'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('VLDL'))
where lower(trim(t.name)) = lower(trim('باقة الدهون والكوليسترول'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Non-HDL Cholesterol'))
where lower(trim(t.name)) = lower(trim('باقة الدهون والكوليسترول'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Total Cholesterol'))
where lower(trim(t.name)) = lower(trim('باقة القلب'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Triglycerides'))
where lower(trim(t.name)) = lower(trim('باقة القلب'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HDL'))
where lower(trim(t.name)) = lower(trim('باقة القلب'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('LDL'))
where lower(trim(t.name)) = lower(trim('باقة القلب'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('hs-CRP'))
where lower(trim(t.name)) = lower(trim('باقة القلب'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HbA1c'))
where lower(trim(t.name)) = lower(trim('باقة القلب'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Creatinine'))
where lower(trim(t.name)) = lower(trim('باقة القلب'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CK-MB'))
where lower(trim(t.name)) = lower(trim('باقة القلب'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('High-Sensitivity Troponin'))
where lower(trim(t.name)) = lower(trim('باقة القلب'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة الغدة الدرقية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Free T4'))
where lower(trim(t.name)) = lower(trim('باقة الغدة الدرقية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Free T3'))
where lower(trim(t.name)) = lower(trim('باقة الغدة الدرقية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Anti-TPO'))
where lower(trim(t.name)) = lower(trim('باقة الغدة الدرقية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Anti-Thyroglobulin'))
where lower(trim(t.name)) = lower(trim('باقة الغدة الدرقية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة صحة المرأة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Ferritin'))
where lower(trim(t.name)) = lower(trim('باقة صحة المرأة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin D'))
where lower(trim(t.name)) = lower(trim('باقة صحة المرأة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin B12'))
where lower(trim(t.name)) = lower(trim('باقة صحة المرأة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة صحة المرأة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة صحة المرأة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HbA1c'))
where lower(trim(t.name)) = lower(trim('باقة صحة المرأة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Total Cholesterol'))
where lower(trim(t.name)) = lower(trim('باقة صحة المرأة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Triglycerides'))
where lower(trim(t.name)) = lower(trim('باقة صحة المرأة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 9
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HDL'))
where lower(trim(t.name)) = lower(trim('باقة صحة المرأة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 10
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('LDL'))
where lower(trim(t.name)) = lower(trim('باقة صحة المرأة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة صحة الرجل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة صحة الرجل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HbA1c'))
where lower(trim(t.name)) = lower(trim('باقة صحة الرجل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Total Cholesterol'))
where lower(trim(t.name)) = lower(trim('باقة صحة الرجل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Triglycerides'))
where lower(trim(t.name)) = lower(trim('باقة صحة الرجل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HDL'))
where lower(trim(t.name)) = lower(trim('باقة صحة الرجل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('LDL'))
where lower(trim(t.name)) = lower(trim('باقة صحة الرجل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Creatinine'))
where lower(trim(t.name)) = lower(trim('باقة صحة الرجل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ALT'))
where lower(trim(t.name)) = lower(trim('باقة صحة الرجل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 9
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('AST'))
where lower(trim(t.name)) = lower(trim('باقة صحة الرجل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 10
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin D'))
where lower(trim(t.name)) = lower(trim('باقة صحة الرجل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 11
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Testosterone Total'))
where lower(trim(t.name)) = lower(trim('باقة صحة الرجل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FSH'))
where lower(trim(t.name)) = lower(trim('باقة الهرمونات النسائية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('LH'))
where lower(trim(t.name)) = lower(trim('باقة الهرمونات النسائية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Prolactin'))
where lower(trim(t.name)) = lower(trim('باقة الهرمونات النسائية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Estradiol'))
where lower(trim(t.name)) = lower(trim('باقة الهرمونات النسائية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Progesterone'))
where lower(trim(t.name)) = lower(trim('باقة الهرمونات النسائية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Testosterone Total'))
where lower(trim(t.name)) = lower(trim('باقة الهرمونات النسائية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة الهرمونات النسائية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Testosterone Total'))
where lower(trim(t.name)) = lower(trim('باقة الهرمونات الرجالية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Free Testosterone'))
where lower(trim(t.name)) = lower(trim('باقة الهرمونات الرجالية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('LH'))
where lower(trim(t.name)) = lower(trim('باقة الهرمونات الرجالية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FSH'))
where lower(trim(t.name)) = lower(trim('باقة الهرمونات الرجالية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('SHBG'))
where lower(trim(t.name)) = lower(trim('باقة الهرمونات الرجالية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Prolactin'))
where lower(trim(t.name)) = lower(trim('باقة الهرمونات الرجالية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة الهرمونات الرجالية'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FSH'))
where lower(trim(t.name)) = lower(trim('باقة الخصوبة للنساء'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('LH'))
where lower(trim(t.name)) = lower(trim('باقة الخصوبة للنساء'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Prolactin'))
where lower(trim(t.name)) = lower(trim('باقة الخصوبة للنساء'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Estradiol'))
where lower(trim(t.name)) = lower(trim('باقة الخصوبة للنساء'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Progesterone'))
where lower(trim(t.name)) = lower(trim('باقة الخصوبة للنساء'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('AMH'))
where lower(trim(t.name)) = lower(trim('باقة الخصوبة للنساء'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة الخصوبة للنساء'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Semen Analysis'))
where lower(trim(t.name)) = lower(trim('باقة الخصوبة للرجال'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Testosterone Total'))
where lower(trim(t.name)) = lower(trim('باقة الخصوبة للرجال'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FSH'))
where lower(trim(t.name)) = lower(trim('باقة الخصوبة للرجال'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('LH'))
where lower(trim(t.name)) = lower(trim('باقة الخصوبة للرجال'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Prolactin'))
where lower(trim(t.name)) = lower(trim('باقة الخصوبة للرجال'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Ferritin'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin D'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin B12'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Rubella IgG'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HBsAg'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HCV Ab'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 9
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('General Urine Examination'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الزواج'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Blood Group ABO'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الزواج'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Rh Factor'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الزواج'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الزواج'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HbA1c'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الزواج'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HBsAg'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الزواج'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HCV Ab'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الزواج'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HIV Ag/Ab'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الزواج'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('VDRL'))
where lower(trim(t.name)) = lower(trim('باقة ما قبل الزواج'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Blood Group ABO'))
where lower(trim(t.name)) = lower(trim('باقة الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Rh Factor'))
where lower(trim(t.name)) = lower(trim('باقة الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Ferritin'))
where lower(trim(t.name)) = lower(trim('باقة الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('General Urine Examination'))
where lower(trim(t.name)) = lower(trim('باقة الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HBsAg'))
where lower(trim(t.name)) = lower(trim('باقة الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HIV Ag/Ab'))
where lower(trim(t.name)) = lower(trim('باقة الحمل'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة كبار السن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة كبار السن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HbA1c'))
where lower(trim(t.name)) = lower(trim('باقة كبار السن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Creatinine'))
where lower(trim(t.name)) = lower(trim('باقة كبار السن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('eGFR'))
where lower(trim(t.name)) = lower(trim('باقة كبار السن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ALT'))
where lower(trim(t.name)) = lower(trim('باقة كبار السن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('AST'))
where lower(trim(t.name)) = lower(trim('باقة كبار السن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Total Cholesterol'))
where lower(trim(t.name)) = lower(trim('باقة كبار السن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('LDL'))
where lower(trim(t.name)) = lower(trim('باقة كبار السن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 9
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة كبار السن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 10
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin D'))
where lower(trim(t.name)) = lower(trim('باقة كبار السن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 11
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin B12'))
where lower(trim(t.name)) = lower(trim('باقة كبار السن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 12
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('General Urine Examination'))
where lower(trim(t.name)) = lower(trim('باقة كبار السن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 13
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('PSA Total'))
where lower(trim(t.name)) = lower(trim('باقة كبار السن'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة الأطفال'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة الأطفال'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Ferritin'))
where lower(trim(t.name)) = lower(trim('باقة الأطفال'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin D'))
where lower(trim(t.name)) = lower(trim('باقة الأطفال'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin B12'))
where lower(trim(t.name)) = lower(trim('باقة الأطفال'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة الأطفال'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('General Urine Examination'))
where lower(trim(t.name)) = lower(trim('باقة الأطفال'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('General Stool Examination'))
where lower(trim(t.name)) = lower(trim('باقة الأطفال'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('FBS'))
where lower(trim(t.name)) = lower(trim('باقة السمنة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HbA1c'))
where lower(trim(t.name)) = lower(trim('باقة السمنة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Fasting Insulin'))
where lower(trim(t.name)) = lower(trim('باقة السمنة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HOMA-IR'))
where lower(trim(t.name)) = lower(trim('باقة السمنة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Total Cholesterol'))
where lower(trim(t.name)) = lower(trim('باقة السمنة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Triglycerides'))
where lower(trim(t.name)) = lower(trim('باقة السمنة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HDL'))
where lower(trim(t.name)) = lower(trim('باقة السمنة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('LDL'))
where lower(trim(t.name)) = lower(trim('باقة السمنة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 8
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ALT'))
where lower(trim(t.name)) = lower(trim('باقة السمنة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 9
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('AST'))
where lower(trim(t.name)) = lower(trim('باقة السمنة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 10
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('TSH'))
where lower(trim(t.name)) = lower(trim('باقة السمنة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 11
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin D'))
where lower(trim(t.name)) = lower(trim('باقة السمنة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة المناعة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CRP'))
where lower(trim(t.name)) = lower(trim('باقة المناعة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ESR'))
where lower(trim(t.name)) = lower(trim('باقة المناعة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ANA'))
where lower(trim(t.name)) = lower(trim('باقة المناعة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('C3'))
where lower(trim(t.name)) = lower(trim('باقة المناعة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('C4'))
where lower(trim(t.name)) = lower(trim('باقة المناعة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Vitamin D'))
where lower(trim(t.name)) = lower(trim('باقة المناعة'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CBC'))
where lower(trim(t.name)) = lower(trim('باقة الالتهابات'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ESR'))
where lower(trim(t.name)) = lower(trim('باقة الالتهابات'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CRP'))
where lower(trim(t.name)) = lower(trim('باقة الالتهابات'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('hs-CRP'))
where lower(trim(t.name)) = lower(trim('باقة الالتهابات'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Procalcitonin'))
where lower(trim(t.name)) = lower(trim('باقة الالتهابات'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('PT'))
where lower(trim(t.name)) = lower(trim('باقة التخثر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('INR'))
where lower(trim(t.name)) = lower(trim('باقة التخثر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('aPTT'))
where lower(trim(t.name)) = lower(trim('باقة التخثر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Fibrinogen'))
where lower(trim(t.name)) = lower(trim('باقة التخثر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('D-Dimer'))
where lower(trim(t.name)) = lower(trim('باقة التخثر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Platelet Count'))
where lower(trim(t.name)) = lower(trim('باقة التخثر'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HBsAg'))
where lower(trim(t.name)) = lower(trim('باقة الفيروسات'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Anti-HBs'))
where lower(trim(t.name)) = lower(trim('باقة الفيروسات'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HCV Ab'))
where lower(trim(t.name)) = lower(trim('باقة الفيروسات'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HIV Ag/Ab'))
where lower(trim(t.name)) = lower(trim('باقة الفيروسات'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('HAV IgM'))
where lower(trim(t.name)) = lower(trim('باقة الفيروسات'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('CMV IgG'))
where lower(trim(t.name)) = lower(trim('باقة الفيروسات'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('EBV'))
where lower(trim(t.name)) = lower(trim('باقة الفيروسات'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 0
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('H. pylori Stool Antigen'))
where lower(trim(t.name)) = lower(trim('باقة صحة الجهاز الهضمي'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 1
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Occult Blood'))
where lower(trim(t.name)) = lower(trim('باقة صحة الجهاز الهضمي'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 2
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('General Stool Examination'))
where lower(trim(t.name)) = lower(trim('باقة صحة الجهاز الهضمي'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 3
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Calprotectin'))
where lower(trim(t.name)) = lower(trim('باقة صحة الجهاز الهضمي'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 4
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Amylase'))
where lower(trim(t.name)) = lower(trim('باقة صحة الجهاز الهضمي'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 5
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('Lipase'))
where lower(trim(t.name)) = lower(trim('باقة صحة الجهاز الهضمي'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 6
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('ALT'))
where lower(trim(t.name)) = lower(trim('باقة صحة الجهاز الهضمي'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );
insert into public.package_template_analyses (template_id, analysis_id, display_order)
select t.id, a.id, 7
from public.package_templates t
join public.analyses a on lower(trim(a.name)) = lower(trim('AST'))
where lower(trim(t.name)) = lower(trim('باقة صحة الجهاز الهضمي'))
  and not exists (
    select 1 from public.package_template_analyses x
    where x.template_id = t.id and x.analysis_id = a.id
  );