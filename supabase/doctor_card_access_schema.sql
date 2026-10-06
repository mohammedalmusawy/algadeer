-- ============================================================
-- دخول المالك: طبيب، مختبر، صيدلية
-- يطبّقه صاحب المشروع في Supabase SQL Editor. لا تشغّله من العميل.
--
-- التعديل العام للمالك معطّل افتراضيًا. أرقام PIN المحلية القديمة
-- ليست إعداد وصول معتمدًا، ولا تُرحَّل إلى تفعيل تلقائي.
-- لا سياسات قراءة/كتابة لـ anon أو authenticated.
-- Edge Function بمفتاح service_role فقط تصل إلى هذه الجداول.
-- كلمات المرور ورموز التفعيل تُخزَّن كبصمات، وليس نصًا واضحًا.
-- ============================================================

create table if not exists public.entity_owner_access (
  entity_type text not null check (entity_type in ('doctor', 'lab', 'pharmacy')),
  entity_id text not null,
  owner_editing_enabled boolean not null default false,
  password_hash text,
  session_version integer not null default 1,
  permissions jsonb not null default '[]'::jsonb,
  activation_code_hash text,
  activation_expires_at timestamptz,
  pharmacy_snapshot jsonb,
  updated_at timestamptz not null default now(),
  primary key (entity_type, entity_id)
);

create table if not exists public.entity_owner_attempts (
  source_hash text not null,
  entity_type text not null check (entity_type in ('doctor', 'lab', 'pharmacy')),
  entity_id text not null,
  kind text not null check (kind in ('password', 'activation')),
  failures integer not null default 0,
  window_started timestamptz not null default now(),
  locked_until timestamptz,
  primary key (source_hash, entity_type, entity_id, kind)
);

alter table public.entity_owner_access enable row level security;
alter table public.entity_owner_attempts enable row level security;

revoke all on table public.entity_owner_access from public, anon, authenticated;
revoke all on table public.entity_owner_attempts from public, anon, authenticated;

grant select, insert, update, delete
  on table public.entity_owner_access to service_role;
grant select, insert, update, delete
  on table public.entity_owner_attempts to service_role;

-- إن نُفِّذ الملف السابق على مشروع تجريبي ولم يُستخدم، يمكن حذف الجدولين
-- doctor_card_credentials و doctor_card_login_attempts يدويًا بعد التأكد.
