-- مراجعة فقط — لا تُطبَّق على الإنتاج من هذا الملف تلقائياً.
-- حقول اختيارية لتوحيد بيانات العقل مع توافق الصفوف القديمة.
-- غياب الأعمدة لا يعطّل التطبيق (العميل يقرأها كسلاسل فارغة إن وُجدت لاحقاً).

-- ALTER TABLE public.doctors
--   ADD COLUMN IF NOT EXISTS name_aliases text NOT NULL DEFAULT '',
--   ADD COLUMN IF NOT EXISTS sub_specialty text NOT NULL DEFAULT '',
--   ADD COLUMN IF NOT EXISTS landmark text NOT NULL DEFAULT '',
--   ADD COLUMN IF NOT EXISTS booking_channel text NOT NULL DEFAULT '',
--   ADD COLUMN IF NOT EXISTS requires_advance_booking boolean NOT NULL DEFAULT false,
--   ADD COLUMN IF NOT EXISTS confirmed_services text NOT NULL DEFAULT '',
--   ADD COLUMN IF NOT EXISTS info_last_verified_at timestamptz;

-- ملاحظات:
-- - name_aliases: صيغ أسماء إضافية مفصولة بفاصلة (لا تخمين).
-- - sub_specialty / age_group موجود جزئياً عبر age_group الحالي.
-- - booking_channel: هاتف / واتساب / حضوري / … من بيانات المالك فقط.
-- - info_last_verified_at: لتلميح «معلومات قديمة» في لوحة الجودة لاحقاً.
-- - لا تملأ أي قيم مختلقة عند الإضافة.
