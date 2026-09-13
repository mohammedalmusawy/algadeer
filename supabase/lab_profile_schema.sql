-- ============================================================
-- غدير كلينك — حقول اختيارية لهوية المختبر
-- آمن / Idempotent / لا يحذف بيانات
-- نفّذه فقط إذا أردت slogan / map_url / working_hours من الإدارة
-- التطبيق يعمل بدون هذا الملف (يقرأ الحقول إن وُجدت ويخفيهاها إن غابت)
-- ============================================================

alter table public.labs
  add column if not exists slogan text not null default '';

alter table public.labs
  add column if not exists map_url text not null default '';

alter table public.labs
  add column if not exists working_hours text not null default '';
