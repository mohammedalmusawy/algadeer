-- ============================================================
-- حماية «اثنين يعدّلون نفس مركز الأشعة بنفس الوقت»
-- نفس فكرة entity_content_revision.sql للأطباء/المختبرات/الصيدليات.
-- يطبّقه صاحب المشروع في Supabase SQL Editor. يضيف عموداً فقط؛
-- لا يحذف ولا يغيّر صفوفاً، وآمن لو تكرر تشغيله.
-- ============================================================

alter table public.radiology_centers
  add column if not exists content_revision integer not null default 1;
