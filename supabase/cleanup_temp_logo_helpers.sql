-- ============================================================
-- غدير كلينك — تنظيف آمن بعد سكربتات اللوغو المؤقتة
-- يحذف فقط الدوال المساعدة لمرة واحدة (ما يمس جداول التطبيق).
-- نفّذه مرة واحدة إذا ظهر تحذير Security على الدوال.
-- ============================================================

-- دوال مساعدة مؤقتة من سكربتات اللوغو (غير مطلوبة وقت التشغيل)
drop function if exists public._is_ghadeer_logo_label(text);
drop function if exists public._strip_ghadeer_logo_label(text);

-- تحقق: لازم يظهر صف واحد على الأقل إذا جدول الأشعة موجود
select
  to_regclass('public.radiology_centers') as radiology_table,
  to_regclass('public.labs') as labs_table,
  to_regclass('public.doctors') as doctors_table;
