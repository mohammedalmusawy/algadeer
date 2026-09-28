-- أيقونات واجهة الغدير القابلة للتغيير من الإدارة.
-- شعار الغدير الرسمي غير مخزَّن هنا — ثابت في التطبيق.
-- نفّذ في Supabase SQL Editor عند الجاهزية. التطبيق يعمل بدون الجدول (رموز افتراضية + كاش محلي).

create table if not exists public.app_ui_icons (
  slot_id text primary key,
  image_url text not null,
  updated_at timestamptz not null default now(),
  constraint app_ui_icons_slot_id_chk check (
    char_length(trim(slot_id)) > 0
    and slot_id not like 'brand.logo%'
    and slot_id <> 'logo'
  ),
  constraint app_ui_icons_image_url_chk check (char_length(trim(image_url)) > 0)
);

comment on table public.app_ui_icons is
  'Override images for UI icon slots (home/specialty/nav). Ghadeer logo is never stored here.';

alter table public.app_ui_icons enable row level security;

-- قراءة عامة للأيقونات الظاهرة في التطبيق.
drop policy if exists "app_ui_icons_public_read" on public.app_ui_icons;
create policy "app_ui_icons_public_read"
  on public.app_ui_icons
  for select
  to anon, authenticated
  using (true);

-- كتابة للإدارة (authenticated). اضبط حسب نظام صلاحياتك إن لزم.
drop policy if exists "app_ui_icons_auth_write" on public.app_ui_icons;
create policy "app_ui_icons_auth_write"
  on public.app_ui_icons
  for all
  to authenticated
  using (true)
  with check (true);

-- تأكد أن bucket clinic-media يسمح بالرفع لمسار ui_icons/ (نفس مخزن الإعلانات).
