-- تنظيف تكرار: صباح مجيد العمري (نفس الهاتف)
-- يبقي السجل الأحدث فقط. نفّذ في Supabase SQL Editor.

delete from public.doctors
where doctor_name = 'صباح مجيد العمري'
  and id <> '5c36ce6a-7bcd-42a9-8d2b-cb7479524399'::uuid
  and id in (
    'fd4aa48d-9ebe-4ea1-9f86-f4120b1ddec6'::uuid,
    '2638c151-c9b8-4507-976e-0b51c2cd2fd6'::uuid,
    '4681d65e-c81c-4e02-b32c-e8893251b560'::uuid,
    '906cac10-f333-4a40-a629-3f85bc1f0dc2'::uuid
  );
