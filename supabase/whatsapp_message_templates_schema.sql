-- ============================================================
-- نماذج رسالة الواتساب — تديرها الإدارة من لوحة التحكم
-- Idempotent. يطبّقه صاحب المشروع بنفسه على المشروع الحي.
--
-- 1) whatsapp_message_templates: نصوص النماذج (حجز، استفسار، ...)
--    المتغيّرات داخل النص: {اسم} اسم المراجع الثلاثي، {الجهة} اسم الطبيب أو المكان.
-- 2) whatsapp_template_section_defaults: النموذج الافتراضي لكل قسم.
-- القراءة عامة (التطبيق يحفظها بالجهاز للشغل بدون إنترنت)،
-- والكتابة للإدارة فقط عبر public.is_clinic_admin().
-- ============================================================

create table if not exists public.whatsapp_message_templates (
  key text primary key,
  title text not null,
  body text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  updated_at timestamptz not null default now(),
  constraint whatsapp_message_templates_key_format
    check (key ~ '^[a-z][a-z0-9_]{1,39}$'),
  constraint whatsapp_message_templates_body_length
    check (char_length(body) between 1 and 600)
);

create table if not exists public.whatsapp_template_section_defaults (
  section text primary key,
  template_key text not null
    references public.whatsapp_message_templates(key) on update cascade,
  updated_at timestamptz not null default now(),
  constraint whatsapp_template_section_defaults_section_check
    check (section in (
      'doctors', 'labs', 'radiology', 'pharmacies', 'physio',
      'supplies', 'optics', 'beauty', 'nursing'
    ))
);

create or replace function public.set_whatsapp_templates_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_whatsapp_message_templates_updated_at
  on public.whatsapp_message_templates;
create trigger trg_whatsapp_message_templates_updated_at
  before update on public.whatsapp_message_templates
  for each row execute function public.set_whatsapp_templates_updated_at();

drop trigger if exists trg_whatsapp_template_section_defaults_updated_at
  on public.whatsapp_template_section_defaults;
create trigger trg_whatsapp_template_section_defaults_updated_at
  before update on public.whatsapp_template_section_defaults
  for each row execute function public.set_whatsapp_templates_updated_at();

alter table public.whatsapp_message_templates enable row level security;
alter table public.whatsapp_template_section_defaults enable row level security;

drop policy if exists whatsapp_message_templates_public_read
  on public.whatsapp_message_templates;
create policy whatsapp_message_templates_public_read
  on public.whatsapp_message_templates for select
  to anon, authenticated
  using (true);

drop policy if exists whatsapp_message_templates_admin_write
  on public.whatsapp_message_templates;
create policy whatsapp_message_templates_admin_write
  on public.whatsapp_message_templates for all
  to authenticated
  using (public.is_clinic_admin())
  with check (public.is_clinic_admin());

drop policy if exists whatsapp_template_section_defaults_public_read
  on public.whatsapp_template_section_defaults;
create policy whatsapp_template_section_defaults_public_read
  on public.whatsapp_template_section_defaults for select
  to anon, authenticated
  using (true);

drop policy if exists whatsapp_template_section_defaults_admin_write
  on public.whatsapp_template_section_defaults;
create policy whatsapp_template_section_defaults_admin_write
  on public.whatsapp_template_section_defaults for all
  to authenticated
  using (public.is_clinic_admin())
  with check (public.is_clinic_admin());

-- بذرة: نموذجا «حجز» و«استفسار» (لا تُكتب فوق نص عدّلته الإدارة)
insert into public.whatsapp_message_templates (key, title, body, sort_order)
values
  ('booking', 'حجز',
   E'السلام عليكم\nأنا {اسم}، أريد حجز عندكم\nحجز عن طريق منصة الغدير', 10),
  ('inquiry', 'استفسار',
   E'السلام عليكم\nأنا {اسم}، أريد استفسار عندكم\nاستفسار عن طريق منصة الغدير', 20)
on conflict (key) do nothing;

-- الافتراضي: «حجز» للأطباء والأشعة والمختبرات والعلاج الطبيعي والتمريض،
-- و«استفسار» للصيدليات والتجهيزات والعوينات والتجميل.
insert into public.whatsapp_template_section_defaults (section, template_key)
values
  ('doctors', 'booking'),
  ('radiology', 'booking'),
  ('labs', 'booking'),
  ('physio', 'booking'),
  ('nursing', 'booking'),
  ('pharmacies', 'inquiry'),
  ('supplies', 'inquiry'),
  ('optics', 'inquiry'),
  ('beauty', 'inquiry')
on conflict (section) do nothing;
