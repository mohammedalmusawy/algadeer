-- ============================================================
-- إجازات الأطباء — متعدد السجلات + مزامنة مع doctors.absence_*
-- Idempotent — لا يمس باقي الجداول
-- ============================================================

create table if not exists public.doctor_absences (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references public.doctors(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  reason text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint doctor_absences_dates_chk check (end_date >= start_date)
);

create index if not exists doctor_absences_doctor_id_idx
  on public.doctor_absences (doctor_id);

create index if not exists doctor_absences_active_range_idx
  on public.doctor_absences (doctor_id, is_active, start_date, end_date);

create or replace function public.set_doctor_absences_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_doctor_absences_updated_at on public.doctor_absences;
create trigger trg_doctor_absences_updated_at
  before update on public.doctor_absences
  for each row
  execute function public.set_doctor_absences_updated_at();

alter table public.doctor_absences enable row level security;

-- قراءة عامة للسجلات المفعّلة (لعرض حالة الطبيب)
drop policy if exists "doctor_absences_public_read" on public.doctor_absences;
create policy "doctor_absences_public_read"
  on public.doctor_absences for select
  to anon, authenticated
  using (is_active = true);

-- إدارة كاملة للمسجّلين
drop policy if exists "doctor_absences_auth_write" on public.doctor_absences;
create policy "doctor_absences_auth_write"
  on public.doctor_absences for all
  to authenticated
  using (true)
  with check (true);

-- ضمان وجود أعمدة المزامنة على doctors (إن لم تكن موجودة)
alter table public.doctors
  add column if not exists absence_from date;

alter table public.doctors
  add column if not exists absence_to date;

-- قراءة/تحديث أعمدة الإجازة من الإدارة
grant select, update on public.doctors to authenticated;

-- ترحيل الفترة الحالية من doctors إلى doctor_absences مرة واحدة إن وُجدت
insert into public.doctor_absences (doctor_id, start_date, end_date, reason, is_active)
select d.id, d.absence_from, d.absence_to, 'مرحّل من السجل السابق', true
from public.doctors d
where d.absence_from is not null
  and d.absence_to is not null
  and d.absence_to >= d.absence_from
  and not exists (
    select 1 from public.doctor_absences a where a.doctor_id = d.id
  );
