-- ============================================================
-- وصف عربي للتحاليل (عام على التحليل وليس خاصًا بباقة واحدة)
-- Idempotent — لا يحذف بيانات
-- ============================================================

alter table public.analyses
  add column if not exists description_ar text not null default '';

-- تعبئة أولية من name_ar إن كان الوصف فارغًا
update public.analyses
set description_ar = name_ar
where coalesce(trim(description_ar), '') = ''
  and coalesce(trim(name_ar), '') <> '';
