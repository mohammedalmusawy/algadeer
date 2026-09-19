-- حقل جنس اختياري للأطباء — لا يغيّر الصفوف الحالية
-- القيمة الافتراضية '' = غير محدد → التطبيق يبقي الصياغة الحالية (مذكر)
alter table public.doctors
  add column if not exists gender text not null default '';

-- قيم مسموحة فقط (فارغ / ذكر / أنثى)
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'doctors_gender_chk'
  ) then
    alter table public.doctors
      add constraint doctors_gender_chk
      check (gender in ('', 'male', 'female'));
  end if;
end $$;

notify pgrst, 'reload schema';
