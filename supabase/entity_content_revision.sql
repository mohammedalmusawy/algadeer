-- ============================================================
-- رقم نسخة للحفظ المتفائل: طبيب، مختبر، باقة، صيدلية
-- يطبّقه صاحب المشروع في Supabase SQL Editor. لا تشغّله من العميل.
-- الحفظ يرفع الرقم فقط إذا طابق الرقم الذي قرأه العميل.
-- ============================================================

alter table public.doctors
  add column if not exists content_revision integer not null default 1;

alter table public.labs
  add column if not exists content_revision integer not null default 1;

alter table public.lab_packages
  add column if not exists content_revision integer not null default 1;

alter table public.pharmacies
  add column if not exists content_revision integer not null default 1;
