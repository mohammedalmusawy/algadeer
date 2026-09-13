-- ============================================================
-- غدير كلينك — توحيد أي image_url = «لوغو الغدير» إلى الشعار المعتمد
-- نفّذه مرة واحدة في Supabase SQL Editor.
-- ============================================================

-- أي نص يقصد لوغو/شعار الغدير → مسار الـ asset المعتمد داخل التطبيق
create or replace function public._is_ghadeer_logo_label(raw text)
returns boolean
language sql
immutable
as $$
  select case
    when raw is null or btrim(raw) = '' then false
    when lower(raw) like '%ghadeer_logo%' then true
    when lower(raw) like '%assets/branding/ghadeer%' then true
    when replace(raw, ' ', '') in (
      'لوغوالغدير', 'لوجوالغدير', 'شعارالغدير',
      'شعارعيادةالغدير', 'لوغوعيادةالغدير', 'لوجوعيادةالغدير'
    ) then true
    when (raw like '%لوغو%' or raw like '%لوجو%' or raw like '%شعار%')
     and raw like '%غدير%' then true
    else false
  end;
$$;

-- مختبرات
update public.labs
set image_url = 'assets/branding/ghadeer_logo.png'
where public._is_ghadeer_logo_label(image_url)
  and coalesce(image_url, '') <> 'assets/branding/ghadeer_logo.png';

-- أطباء
update public.doctors
set image_url = 'assets/branding/ghadeer_logo.png'
where public._is_ghadeer_logo_label(image_url)
  and coalesce(image_url, '') <> 'assets/branding/ghadeer_logo.png';

-- مراكز أشعة (إن وُجد الجدول)
do $$
begin
  if to_regclass('public.radiology_centers') is not null then
    execute $q$
      update public.radiology_centers
      set image_url = 'assets/branding/ghadeer_logo.png'
      where public._is_ghadeer_logo_label(image_url)
        and coalesce(image_url, '') <> 'assets/branding/ghadeer_logo.png'
    $q$;
  end if;
end $$;

-- باقات
do $$
begin
  if to_regclass('public.lab_packages') is not null then
    execute $q$
      update public.lab_packages
      set image_url = 'assets/branding/ghadeer_logo.png'
      where public._is_ghadeer_logo_label(image_url)
        and coalesce(image_url, '') <> 'assets/branding/ghadeer_logo.png'
    $q$;
  end if;
end $$;

-- تحقق سريع
select 'labs' as src, count(*) as logo_rows
from public.labs
where image_url = 'assets/branding/ghadeer_logo.png'
union all
select 'doctors', count(*)
from public.doctors
where image_url = 'assets/branding/ghadeer_logo.png';
