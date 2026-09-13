-- ============================================================
-- غدير كلينك — تنظيف نص «[لوغو الغدير]» من النبذة/الشعار
-- والصور إن وُجدت. نفّذه مرة واحدة في SQL Editor.
-- ملاحظة: التطبيق يعرض الشعار مكان النص حتى بدون هذا الملف،
-- لكن التنظيف يجعل البيانات أوضح في الإدارة.
-- ============================================================

create or replace function public._strip_ghadeer_logo_label(raw text)
returns text
language sql
immutable
as $$
  select nullif(
    btrim(
      regexp_replace(
        regexp_replace(
          coalesce(raw, ''),
          '\[\s*(لوغو|لوجو|شعار)\s*الغدير\s*\]',
          ' ',
          'g'
        ),
        '(لوغو|لوجو|شعار)\s+(عيادة\s+)?الغدير',
        ' ',
        'g'
      )
    ),
    ''
  );
$$;

-- أشعة: شعار + نبذة
do $$
begin
  if to_regclass('public.radiology_centers') is not null then
    execute $q$
      update public.radiology_centers
      set
        slogan = coalesce(public._strip_ghadeer_logo_label(slogan), ''),
        description = coalesce(public._strip_ghadeer_logo_label(description), description)
      where slogan ~ 'لوغو|لوجو|شعار' or description ~ 'لوغو|لوجو|شعار'
    $q$;

    execute $q$
      update public.radiology_centers
      set image_url = 'assets/branding/ghadeer_logo.png'
      where image_url is not null
        and (
          image_url ilike '%ghadeer_logo%'
          or image_url ~ 'لوغو|لوجو'
          or btrim(image_url) in ('لوغو الغدير', 'لوجو الغدير', '[لوغو الغدير]')
        )
    $q$;
  end if;
end $$;

-- مختبرات
update public.labs
set
  slogan = coalesce(public._strip_ghadeer_logo_label(slogan), ''),
  description = coalesce(public._strip_ghadeer_logo_label(description), description)
where slogan ~ 'لوغو|لوجو|شعار' or description ~ 'لوغو|لوجو|شعار';

-- تحقق
select id, name, slogan, left(description, 80) as description_preview
from public.radiology_centers
order by display_order, name
limit 10;
