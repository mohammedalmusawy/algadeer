-- ============================================================
-- مواقع التواصل + الموقع الإلكتروني (طبيب / مختبر / أشعة)
-- آمن مع IF NOT EXISTS — يمكن إعادة التنفيذ.
--
-- إذا نفّذت النسخة السابقة (بدون website): يكفي الأسطر الخاصة
-- بـ website_url فقط في الأسفل تحت «ترقية فقط».
-- الصيدليات محلية — لا تحتاج هذا الملف.
-- ============================================================

alter table public.doctors
  add column if not exists website_url text default '',
  add column if not exists instagram_url text default '',
  add column if not exists facebook_url text default '',
  add column if not exists tiktok_url text default '',
  add column if not exists telegram_url text default '';

alter table public.labs
  add column if not exists website_url text default '',
  add column if not exists instagram_url text default '',
  add column if not exists facebook_url text default '',
  add column if not exists tiktok_url text default '',
  add column if not exists telegram_url text default '';

alter table public.radiology_centers
  add column if not exists website_url text default '',
  add column if not exists instagram_url text default '',
  add column if not exists facebook_url text default '',
  add column if not exists tiktok_url text default '',
  add column if not exists telegram_url text default '';

-- ------------------------------------------------------------
-- ترقية فقط (إن كانت الأعمدة الأربعة موجودة مسبقاً):
-- ------------------------------------------------------------
-- alter table public.doctors add column if not exists website_url text default '';
-- alter table public.labs add column if not exists website_url text default '';
-- alter table public.radiology_centers add column if not exists website_url text default '';
