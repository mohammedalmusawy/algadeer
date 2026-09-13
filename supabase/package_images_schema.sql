-- ============================================================
-- صور الباقات: image_url + مكتبة مقترحة + Storage packages/
-- Idempotent — لا يمس doctors/ أو labs/
-- ============================================================

alter table public.lab_packages
  add column if not exists image_url text not null default '';

create table if not exists public.package_images (
  id text primary key,
  title text not null,
  category text not null default 'general',
  image_url text not null,
  keywords text[] not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.package_images enable row level security;

drop policy if exists "package_images_public_read" on public.package_images;
create policy "package_images_public_read"
  on public.package_images for select
  using (is_active = true);

drop policy if exists "package_images_auth_write" on public.package_images;
create policy "package_images_auth_write"
  on public.package_images for all
  to authenticated
  using (true)
  with check (true);

insert into public.package_images (id, title, category, image_url, keywords, is_active)
values
  ('general', 'فحص شامل / مختبر', 'general',
   'https://images.unsplash.com/photo-1579684385127-1ef15d508118?auto=format&fit=crop&w=900&q=80',
   array['general','checkup','lab','medical','شامل','فحص','مختبر','تحاليل'], true),
  ('heart', 'صحة القلب', 'heart',
   'https://images.unsplash.com/photo-1628348068343-c358b319181f?auto=format&fit=crop&w=900&q=80',
   array['heart','cardiac','ecg','cardiovascular','قلب','قلبية','شرايين'], true),
  ('vitamin_d', 'فيتامين D', 'vitamins',
   'https://images.unsplash.com/photo-1550572017-edd951aa8f72?auto=format&fit=crop&w=900&q=80',
   array['vitamin d','vitamind','sun','فيتامين د','فيتامين d','شمس'], true),
  ('hair', 'تساقط الشعر', 'hair',
   'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?auto=format&fit=crop&w=900&q=80',
   array['hair','scalp','hair loss','شعر','تساقط','فروة'], true),
  ('thyroid', 'الغدة الدرقية', 'thyroid',
   'https://images.unsplash.com/photo-1582719471384-894fbb16e074?auto=format&fit=crop&w=900&q=80',
   array['thyroid','tsh','غدة','درقية','thyroid gland'], true),
  ('diabetes', 'السكري', 'diabetes',
   'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?auto=format&fit=crop&w=900&q=80',
   array['diabetes','glucose','sugar','hba1c','سكري','سكر','جلوكوز'], true),
  ('joints', 'المفاصل والعظام', 'joints',
   'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?auto=format&fit=crop&w=900&q=80',
   array['joint','bone','rheumatology','مفاصل','عظام','روماتيزم'], true),
  ('kidney', 'الكلى', 'kidney',
   'https://images.unsplash.com/photo-1559757175-5700dde97648?auto=format&fit=crop&w=900&q=80',
   array['kidney','renal','كلى','كلية','وظائف الكلى'], true),
  ('liver', 'الكبد', 'liver',
   'https://images.unsplash.com/photo-1581594693702-fbdc51b2763b?auto=format&fit=crop&w=900&q=80',
   array['liver','hepatic','alt','ast','كبد','وظائف الكبد'], true),
  ('anemia', 'فقر الدم', 'anemia',
   'https://images.unsplash.com/photo-1615461066159-fea0960485d5?auto=format&fit=crop&w=900&q=80',
   array['anemia','blood','iron','rbc','cbc','فقر','دم','حديد'], true),
  ('vitamins', 'فيتامينات ومعادن', 'vitamins',
   'https://images.unsplash.com/photo-1471864190281-a93a3070b6de?auto=format&fit=crop&w=900&q=80',
   array['vitamins','minerals','vitamin','فيتامينات','معادن','تغذية'], true),
  ('sports', 'الرياضيين', 'sports',
   'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?auto=format&fit=crop&w=900&q=80',
   array['sports','fitness','athlete','muscle','رياض','رياضيين','لياقة'], true),
  ('women', 'صحة المرأة', 'women',
   'https://images.unsplash.com/photo-1576091160550-2173dba999ef?auto=format&fit=crop&w=900&q=80',
   array['women','woman','female','امرأة','المرأة','نسائية'], true),
  ('men', 'صحة الرجل', 'men',
   'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?auto=format&fit=crop&w=900&q=80',
   array['men','man','male','رجل','الرجل','رجالية'], true),
  ('children', 'الأطفال', 'children',
   'https://images.unsplash.com/photo-1503454537195-1dcabb73ffb9?auto=format&fit=crop&w=900&q=80',
   array['children','pediatric','kids','child','أطفال','طفل'], true),
  ('seniors', 'كبار السن', 'seniors',
   'https://images.unsplash.com/photo-1581579438747-1dc8d17bbce4?auto=format&fit=crop&w=900&q=80',
   array['senior','elderly','aging','كبار','مسنين','شيخوخة'], true)
on conflict (id) do update set
  title = excluded.title,
  category = excluded.category,
  image_url = excluded.image_url,
  keywords = excluded.keywords,
  is_active = excluded.is_active;

-- Storage: packages/ داخل clinic-media (لا يمس labs/ أو doctors/)
drop policy if exists "clinic_media_packages_public_read" on storage.objects;
create policy "clinic_media_packages_public_read"
  on storage.objects for select
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'packages'
  );

drop policy if exists "clinic_media_packages_auth_insert" on storage.objects;
create policy "clinic_media_packages_auth_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'packages'
  );

drop policy if exists "clinic_media_packages_auth_update" on storage.objects;
create policy "clinic_media_packages_auth_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'packages'
  )
  with check (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'packages'
  );

drop policy if exists "clinic_media_packages_auth_delete" on storage.objects;
create policy "clinic_media_packages_auth_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'clinic-media'
    and (storage.foldername(name))[1] = 'packages'
  );
