-- ============================================================
-- غدير كلينك — توسيع قاموس التحاليل + ترتيب الشهرة (العراق)
-- نفّذه في Supabase SQL Editor مرة واحدة (Idempotent).
-- يبدأ بالأشهر: CBC ثم باطنية/مفاصل الشائعة.
-- لا يحذف بيانات موجودة.
-- ============================================================

-- 1) عمود ترتيب العرض (الأصغر = أظهر أولاً)
alter table public.analyses
  add column if not exists display_order integer not null default 9999;

create index if not exists analyses_display_order_idx
  on public.analyses (display_order, lower(trim(name)));

-- 2) تحاليل إضافية شائعة في العراق (باطنية + مفاصل + عامة)
with seed(name, short_name, name_ar, category, description, aliases) as (
  values
  -- لوحات يطلبها الأطباء بالاسم الشائع
  ('Lipid Profile', 'Lipids', 'تحليل الدهون الكامل', 'LIPIDS', 'Full lipid profile panel', ARRAY['دهون الدم','بروفيل الدهون','Lipids','كوليسترول ودهون']::text[]),
  ('Liver Function Tests', 'LFT', 'وظائف الكبد', 'LIVER', 'Liver function panel', ARRAY['LFT','LFTs','وظائف كبد','إنزيمات الكبد']::text[]),
  ('Renal Function Tests', 'RFT', 'وظائف الكلى', 'KIDNEY', 'Renal function panel', ARRAY['RFT','RFTs','KFT','وظائف كلى','يوريا وكرياتينين']::text[]),
  ('Electrolytes Panel', 'Lytes', 'الشوارد الكهربائية', 'ELECTROLYTES', 'Na K Cl electrolytes', ARRAY['Electrolytes','U&E','شوارد','أملاح الدم']::text[]),
  ('Blood Sugar', 'BS', 'السكر في الدم', 'DIABETES', 'Blood glucose (generic)', ARRAY['Glucose','سكر الدم','فحص السكر']::text[]),

  -- باطنية شائعة إضافية
  ('Homocysteine', 'Hcy', 'الهوموسيستين', 'CARDIAC', 'Homocysteine', ARRAY['هوموسيستين','Homocystine']::text[]),
  ('Malaria smear', 'Malaria', 'مسحة الملاريا', 'INFECTIOUS', 'Malaria blood film', ARRAY['Malaria','ملاريا','Blood Film Malaria']::text[]),
  ('Rose Bengal', 'Rose Bengal', 'روز بنغال', 'SEROLOGY', 'Brucella Rose Bengal', ARRAY['روزبنغال','بروسيلا سريع']::text[]),
  ('Wright Test', 'Wright', 'رايت', 'SEROLOGY', 'Wright agglutination (Brucella)', ARRAY['رايت','Wright Agglutination']::text[]),
  ('Typhidot', 'Typhidot', 'تيفيدوت', 'SEROLOGY', 'Typhoid rapid test', ARRAY['Typhoid IgM','تيفوئيد سريع']::text[]),
  ('Quantiferon TB', 'QFT', 'كوانتيفيرون سل', 'INFECTIOUS', 'QuantiFERON-TB Gold', ARRAY['IGRA','Quantiferon','سل كامن','TB Gold']::text[]),
  ('Mantoux Test', 'PPD', 'مانتو / توبركلين', 'INFECTIOUS', 'Tuberculin skin test', ARRAY['PPD','TST','توبركلين','مانتو']::text[]),
  ('Blood Film for Parasites', 'BF', 'مسحة الدم للطفيليات', 'HEMATOLOGY', 'Blood film parasites', ARRAY['Blood Film','طفيليات الدم']::text[]),
  ('Serum Protein Electrophoresis', 'SPEP', 'ترحيل بروتينات الدم', 'OTHER', 'Serum protein electrophoresis', ARRAY['SPE','Protein Electrophoresis','ترحيل بروتين']::text[]),
  ('IgE Total', 'IgE', 'الغلوبولين IgE الكلي', 'ALLERGY', 'Total IgE', ARRAY['Total IgE','حساسية','IgE']::text[]),
  ('IgA', 'IgA', 'الغلوبولين IgA', 'IMMUNOLOGY', 'Immunoglobulin A', ARRAY['Immunoglobulin A']::text[]),
  ('IgG', 'IgG', 'الغلوبولين IgG', 'IMMUNOLOGY', 'Immunoglobulin G', ARRAY['Immunoglobulin G']::text[]),
  ('IgM', 'IgM', 'الغلوبولين IgM', 'IMMUNOLOGY', 'Immunoglobulin M', ARRAY['Immunoglobulin M']::text[]),
  ('AFP', 'AFP', 'ألفا فيتو بروتين', 'TUMOR', 'Alpha-fetoprotein', ARRAY['Alpha Fetoprotein','AFP']::text[]),
  ('CEA', 'CEA', 'المستضد السرطاني الجنيني', 'TUMOR', 'Carcinoembryonic antigen', ARRAY['CEA']::text[]),
  ('CA-125', 'CA125', 'المستضد CA-125', 'TUMOR', 'Cancer antigen 125', ARRAY['CA125','CA 125']::text[]),
  ('CA 19-9', 'CA19-9', 'المستضد CA 19-9', 'TUMOR', 'Cancer antigen 19-9', ARRAY['CA19-9','CA19.9']::text[]),
  ('CA 15-3', 'CA15-3', 'المستضد CA 15-3', 'TUMOR', 'Cancer antigen 15-3', ARRAY['CA15-3','CA15.3']::text[]),
  ('Beta-2 Microglobulin', 'B2M', 'بيتا 2 مايكروغلوبولين', 'OTHER', 'Beta-2 microglobulin', ARRAY['B2M','β2 Microglobulin']::text[]),
  ('2-Hour Postprandial Glucose', '2HPP', 'سكر بعد ساعتين', 'DIABETES', '2-hour postprandial glucose', ARRAY['2HPP','2HPPG','سكر بعد ساعتين']::text[]),
  ('OGCT', 'OGCT', 'فحص سكر الحمل', 'DIABETES', 'Oral glucose challenge test', ARRAY['Glucose Challenge','سكر حمل']::text[]),
  ('HCV RNA PCR', 'HCV PCR', 'فيروس التهاب الكبد C PCR', 'HEPATITIS', 'HCV viral load PCR', ARRAY['HCV PCR','HCV RNA']::text[]),
  ('HBV DNA PCR', 'HBV PCR', 'فيروس التهاب الكبد B PCR', 'HEPATITIS', 'HBV viral load PCR', ARRAY['HBV PCR','HBV DNA']::text[]),
  ('COVID-19 PCR', 'COVID PCR', 'فحص كورونا PCR', 'INFECTIOUS', 'SARS-CoV-2 PCR', ARRAY['COVID PCR','كورونا','SARS-CoV-2']::text[]),
  ('COVID-19 Antibody', 'COVID Ab', 'أجسام مضادة لكورونا', 'INFECTIOUS', 'SARS-CoV-2 antibodies', ARRAY['COVID Ab','مضاد كورونا']::text[]),

  -- روماتيزم / مفاصل مهمة إضافية
  ('HLA-B27', 'HLA-B27', 'مستضد HLA-B27', 'RHEUMATOLOGY', 'HLA-B27 typing', ARRAY['HLAB27','HLA B27','التهاب فقرات']::text[]),
  ('ANCA', 'ANCA', 'الأجسام المضادة للسيتوبلازم', 'RHEUMATOLOGY', 'ANCA screen', ARRAY['c-ANCA','p-ANCA','ANCA Screen']::text[]),
  ('c-ANCA / PR3', 'PR3', 'c-ANCA (PR3)', 'RHEUMATOLOGY', 'PR3-ANCA', ARRAY['PR3','cANCA','Anti-PR3']::text[]),
  ('p-ANCA / MPO', 'MPO', 'p-ANCA (MPO)', 'RHEUMATOLOGY', 'MPO-ANCA', ARRAY['MPO','pANCA','Anti-MPO']::text[]),
  ('ENA Screen', 'ENA', 'فحص ENA', 'RHEUMATOLOGY', 'Extractable nuclear antigens screen', ARRAY['ENA','ENA Panel']::text[]),
  ('Anti-Ro / SSA', 'Anti-Ro', 'مضاد Ro (SSA)', 'RHEUMATOLOGY', 'Anti-Ro/SSA', ARRAY['Anti-SSA','Anti Ro','SSA']::text[]),
  ('Anti-La / SSB', 'Anti-La', 'مضاد La (SSB)', 'RHEUMATOLOGY', 'Anti-La/SSB', ARRAY['Anti-SSB','Anti La','SSB']::text[]),
  ('Anti-Sm', 'Anti-Sm', 'مضاد Sm', 'RHEUMATOLOGY', 'Anti-Smith antibody', ARRAY['Anti Smith','Sm Ab']::text[]),
  ('Anti-RNP', 'Anti-RNP', 'مضاد RNP', 'RHEUMATOLOGY', 'Anti-RNP antibody', ARRAY['Anti RNP','RNP Ab']::text[]),
  ('Anti-Scl-70', 'Scl-70', 'مضاد Scl-70', 'RHEUMATOLOGY', 'Anti-Scl-70', ARRAY['Anti Topoisomerase','Scl70']::text[]),
  ('Anti-Jo-1', 'Jo-1', 'مضاد Jo-1', 'RHEUMATOLOGY', 'Anti-Jo-1', ARRAY['Anti Jo1','Jo1']::text[]),
  ('Lupus Anticoagulant', 'LA', 'مضاد التخثر الذئبي', 'RHEUMATOLOGY', 'Lupus anticoagulant', ARRAY['LA','LAC','ذئبة تخثر']::text[]),
  ('Anti-Cardiolipin IgG', 'aCL IgG', 'مضاد كارديوليبين IgG', 'RHEUMATOLOGY', 'Anti-cardiolipin IgG', ARRAY['ACL IgG','Cardiolipin IgG']::text[]),
  ('Anti-Cardiolipin IgM', 'aCL IgM', 'مضاد كارديوليبين IgM', 'RHEUMATOLOGY', 'Anti-cardiolipin IgM', ARRAY['ACL IgM','Cardiolipin IgM']::text[]),
  ('Anti-Beta2 Glycoprotein IgG', 'B2GP IgG', 'مضاد بيتا2 غليكوبروتين IgG', 'RHEUMATOLOGY', 'Anti-β2 glycoprotein IgG', ARRAY['Anti B2GP','B2GPI IgG']::text[]),
  ('Anti-Beta2 Glycoprotein IgM', 'B2GP IgM', 'مضاد بيتا2 غليكوبروتين IgM', 'RHEUMATOLOGY', 'Anti-β2 glycoprotein IgM', ARRAY['B2GPI IgM']::text[]),
  ('CH50', 'CH50', 'المتممة الكلية CH50', 'RHEUMATOLOGY', 'Total complement activity', ARRAY['CH50','Total Complement']::text[]),
  ('HLA-B51', 'HLA-B51', 'مستضد HLA-B51', 'RHEUMATOLOGY', 'HLA-B51 (Behcet)', ARRAY['HLAB51','Behçet','بهجت']::text[]),
  ('Uric Acid 24h Urine', '24h UA', 'حمض اليوريك ببول 24 ساعة', 'KIDNEY', '24-hour urine uric acid', ARRAY['Urine Uric Acid','يوريك بول']::text[]),
  ('Joint Fluid Analysis', 'SF', 'تحليل السائل الزليلي', 'RHEUMATOLOGY', 'Synovial fluid analysis', ARRAY['Synovial Fluid','سائل مفصل']::text[]),
  ('Crystal Exam Synovial Fluid', 'Crystals', 'بلورات السائل الزليلي', 'RHEUMATOLOGY', 'Synovial fluid crystals', ARRAY['MSU','CPPD','بلورات نقرس']::text[])
)
insert into public.analyses (name, short_name, name_ar, category, description, aliases, is_active, display_order)
select s.name, s.short_name, s.name_ar, s.category, s.description, s.aliases, true, 9999
from seed s
where not exists (
  select 1 from public.analyses a where lower(trim(a.name)) = lower(trim(s.name))
);

-- تحديث الحقول للتحاليل الجديدة إن وُجدت مسبقًا بأسماء قريبة
with seed(name, short_name, name_ar, category, description, aliases) as (
  values
  ('Lipid Profile', 'Lipids', 'تحليل الدهون الكامل', 'LIPIDS', 'Full lipid profile panel', ARRAY['دهون الدم','بروفيل الدهون','Lipids','كوليسترول ودهون']::text[]),
  ('Liver Function Tests', 'LFT', 'وظائف الكبد', 'LIVER', 'Liver function panel', ARRAY['LFT','LFTs','وظائف كبد','إنزيمات الكبد']::text[]),
  ('Renal Function Tests', 'RFT', 'وظائف الكلى', 'KIDNEY', 'Renal function panel', ARRAY['RFT','RFTs','KFT','وظائف كلى','يوريا وكرياتينين']::text[]),
  ('HLA-B27', 'HLA-B27', 'مستضد HLA-B27', 'RHEUMATOLOGY', 'HLA-B27 typing', ARRAY['HLAB27','HLA B27','التهاب فقرات']::text[]),
  ('ANCA', 'ANCA', 'الأجسام المضادة للسيتوبلازم', 'RHEUMATOLOGY', 'ANCA screen', ARRAY['c-ANCA','p-ANCA','ANCA Screen']::text[]),
  ('ENA Screen', 'ENA', 'فحص ENA', 'RHEUMATOLOGY', 'Extractable nuclear antigens screen', ARRAY['ENA','ENA Panel']::text[]),
  ('Homocysteine', 'Hcy', 'الهوموسيستين', 'CARDIAC', 'Homocysteine', ARRAY['هوموسيستين','Homocystine']::text[]),
  ('Quantiferon TB', 'QFT', 'كوانتيفيرون سل', 'INFECTIOUS', 'QuantiFERON-TB Gold', ARRAY['IGRA','Quantiferon','سل كامن','TB Gold']::text[]),
  ('Rose Bengal', 'Rose Bengal', 'روز بنغال', 'SEROLOGY', 'Brucella Rose Bengal', ARRAY['روزبنغال','بروسيلا سريع']::text[]),
  ('Wright Test', 'Wright', 'رايت', 'SEROLOGY', 'Wright agglutination (Brucella)', ARRAY['رايت','Wright Agglutination']::text[])
)
update public.analyses a
set
  short_name = s.short_name,
  name_ar = s.name_ar,
  category = s.category,
  description = s.description,
  aliases = s.aliases,
  is_active = true
from seed s
where lower(trim(a.name)) = lower(trim(s.name));

-- 3) ترتيب الشهرة: باطنية + مفاصل أولاً (CBC في المقدمة)
with popularity(name, ord) as (
  values
  -- أساسيات يومية
  ('CBC', 1),
  ('ESR', 2),
  ('CRP', 3),
  ('hs-CRP', 4),
  ('General Urine Examination', 5),
  ('FBS', 6),
  ('RBS', 7),
  ('Blood Sugar', 8),
  ('HbA1c', 9),
  ('PPBS', 10),
  ('2-Hour Postprandial Glucose', 11),

  -- كلى / شوارد / كبد / دهون (باطنية)
  ('Renal Function Tests', 12),
  ('Urea', 13),
  ('Creatinine', 14),
  ('eGFR', 15),
  ('Uric Acid', 16),
  ('Electrolytes Panel', 17),
  ('Sodium', 18),
  ('Potassium', 19),
  ('Chloride', 20),
  ('Calcium', 21),
  ('Magnesium', 22),
  ('Phosphorus', 23),
  ('Liver Function Tests', 24),
  ('ALT', 25),
  ('AST', 26),
  ('ALP', 27),
  ('GGT', 28),
  ('Total Bilirubin', 29),
  ('Direct Bilirubin', 30),
  ('Albumin', 31),
  ('Total Protein', 32),
  ('Lipid Profile', 33),
  ('Total Cholesterol', 34),
  ('Triglycerides', 35),
  ('HDL', 36),
  ('LDL', 37),
  ('VLDL', 38),

  -- غدة / فيتامينات / حديد
  ('TSH', 39),
  ('Free T4', 40),
  ('Free T3', 41),
  ('T3', 42),
  ('T4', 43),
  ('Anti-TPO', 44),
  ('Vitamin D', 45),
  ('Vitamin B12', 46),
  ('Folate', 47),
  ('Ferritin', 48),
  ('Serum Iron', 49),
  ('TIBC', 50),
  ('Transferrin Saturation', 51),

  -- مفاصل / روماتيزم (أولوية عالية)
  ('RF', 52),
  ('Anti-CCP', 53),
  ('ANA', 54),
  ('ASO', 55),
  ('HLA-B27', 56),
  ('Anti-dsDNA', 57),
  ('C3', 58),
  ('C4', 59),
  ('ENA Screen', 60),
  ('Anti-Ro / SSA', 61),
  ('Anti-La / SSB', 62),
  ('Anti-Sm', 63),
  ('Anti-RNP', 64),
  ('ANCA', 65),
  ('c-ANCA / PR3', 66),
  ('p-ANCA / MPO', 67),
  ('Lupus Anticoagulant', 68),
  ('Anti-Cardiolipin IgG', 69),
  ('Anti-Cardiolipin IgM', 70),
  ('Anti-Scl-70', 71),
  ('Anti-Jo-1', 72),
  ('HLA-B51', 73),
  ('Joint Fluid Analysis', 74),
  ('Crystal Exam Synovial Fluid', 75),

  -- جهاز هضمي / إنتانات شائعة بالعراق
  ('H. pylori Stool Antigen', 76),
  ('H. pylori Antibody', 77),
  ('H. pylori Breath Test', 78),
  ('General Stool Examination', 79),
  ('Occult Blood', 80),
  ('Ova & Parasites', 81),
  ('Amylase', 82),
  ('Lipase', 83),
  ('Widal', 84),
  ('Typhidot', 85),
  ('Brucella', 86),
  ('Rose Bengal', 87),
  ('Wright Test', 88),
  ('Malaria smear', 89),
  ('Blood Film for Parasites', 90),
  ('Quantiferon TB', 91),
  ('Mantoux Test', 92),

  -- فيروسات كبد / دم
  ('HBsAg', 93),
  ('HCV Ab', 94),
  ('HIV Ag/Ab', 95),
  ('HBV DNA PCR', 96),
  ('HCV RNA PCR', 97),
  ('Blood Group ABO', 98),
  ('Rh Factor', 99),
  ('Peripheral Blood Film', 100),
  ('Hemoglobin', 101),
  ('Platelet Count', 102),
  ('WBC Count', 103),

  -- تخثر / قلب
  ('PT', 104),
  ('INR', 105),
  ('aPTT', 106),
  ('D-Dimer', 107),
  ('Troponin I', 108),
  ('High-Sensitivity Troponin', 109),
  ('CK-MB', 110),
  ('Homocysteine', 111),
  ('NT-proBNP', 112),

  -- هرمونات / أورام شائعة
  ('Prolactin', 113),
  ('Cortisol', 114),
  ('Testosterone Total', 115),
  ('Beta-hCG Quantitative', 116),
  ('Pregnancy Test', 117),
  ('PSA Total', 118),
  ('AFP', 119),
  ('CEA', 120),
  ('CA-125', 121),
  ('CA 19-9', 122),
  ('CA 15-3', 123),
  ('IgE Total', 124),
  ('Serum Protein Electrophoresis', 125),
  ('G6PD', 126),
  ('Sickle Cell Screen', 127),
  ('Urine Culture', 128),
  ('Blood Culture', 129),
  ('COVID-19 PCR', 130),
  ('COVID-19 Antibody', 131)
)
update public.analyses a
set display_order = p.ord
from popularity p
where lower(trim(a.name)) = lower(trim(p.name));

-- أي تحليل بلا ترتيب شهرة يبقى في الذيل
update public.analyses
set display_order = 9999
where display_order is null or display_order < 1;

-- 4) تحديث search_text
update public.analyses
set search_text = lower(trim(concat_ws(' ',
  name,
  coalesce(short_name, ''),
  coalesce(name_ar, ''),
  coalesce(category, ''),
  coalesce(description, ''),
  array_to_string(coalesce(aliases, '{}'::text[]), ' ')
)));
