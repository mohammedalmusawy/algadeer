-- ============================================================
-- غدير — فحص جودة بيانات التواجد اليومي للأطباء (READ-ONLY)
-- كله SELECT فقط: لا يعدّل جدولًا ولا بيانات ولا schema.
-- نفّذه في Supabase SQL Editor واحدًا واحدًا (أو دفعة واحدة) وراجع النتائج.
-- يخدم: سؤال «هل دكتورة ميعاد متواجدة اليوم؟» في مساعد البحث والتنفيذ.
-- ============================================================

-- 1) أعمدة التواجد الموجودة فعلًا ونوعها
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'doctors'
  and column_name in (
    'working_days', 'working_hours', 'booking_status',
    'absence_from', 'absence_to', 'is_active', 'gender',
    'profile_views', 'call_taps', 'whatsapp_taps'
  )
order by column_name;

-- 2) توزيع booking_status (المتوقع: available | full | walk_in_only | unavailable)
select coalesce(booking_status::text, '<NULL>') as booking_status, count(*) as doctors
from public.doctors
group by 1
order by 2 desc;

-- 3) كم طبيبًا بلا جدول أصلًا (لا days ولا hours) → الجواب سيكون «لا معلومة مؤكدة»
select
  count(*) as total_doctors,
  count(*) filter (
    where coalesce(trim(working_hours), '') = '' and coalesce(trim(working_days), '') = ''
  ) as no_schedule_at_all,
  count(*) filter (
    where coalesce(trim(working_hours), '') = '' and coalesce(trim(working_days), '') <> ''
  ) as days_only_no_period,
  count(*) filter (where coalesce(trim(working_hours), '') <> '') as has_hours
from public.doctors;

-- 4) working_hours بصيغة غير مقروءة: نص موجود لكن لا يحتوي اسم يوم
select id, doctor_name, working_days, working_hours
from public.doctors
where coalesce(trim(working_hours), '') <> ''
  and working_hours !~ '(السبت|الأحد|الاثنين|الثلاثاء|الأربعاء|الخميس|الجمعة)'
limit 50;

-- 5) أيام مذكورة بلا فترة مفهومة (صباحًا/مساءً/عطلة/إجازة) بعد اسم اليوم
select id, doctor_name, working_hours
from public.doctors
where coalesce(trim(working_hours), '') <> ''
  and working_hours ~ '(السبت|الأحد|الاثنين|الثلاثاء|الأربعاء|الخميس|الجمعة)'
  and working_hours !~ '(صباح|مساء|عطل|اجاز|إجاز)'
limit 50;

-- 6) عيّنة للمراجعة البصرية (كيف كُتبت الجداول فعليًا)
select doctor_name, working_days, working_hours, booking_status
from public.doctors
order by doctor_name
limit 40;

-- 7) الإجازة: صفوف ناقصة أو متناقضة في doctors.absence_from/absence_to
select
  count(*) filter (where absence_from is not null and absence_to is null) as from_without_to,
  count(*) filter (where absence_from is null and absence_to is not null) as to_without_from,
  count(*) filter (
    where absence_from is not null and absence_to is not null
      and absence_from::text > absence_to::text
  ) as from_after_to
from public.doctors;

-- 8) من هو في إجازة «اليوم» بتوقيت بغداد (نفس منطق التطبيق)
select id, doctor_name, absence_from, absence_to
from public.doctors
where absence_from is not null and absence_to is not null
  and left(absence_from::text, 10) <= to_char((now() at time zone 'Asia/Baghdad')::date, 'YYYY-MM-DD')
  and left(absence_to::text, 10)   >= to_char((now() at time zone 'Asia/Baghdad')::date, 'YYYY-MM-DD')
order by doctor_name;

-- 9) اتساق جدول doctor_absences مع doctors.absence_* (إن كان الجدول موجودًا)
select to_regclass('public.doctor_absences') as doctor_absences_table;
-- إن رجع الاسم (وليس NULL) نفّذ:
-- select d.id, d.doctor_name, d.absence_from, d.absence_to
-- from public.doctors d
-- where d.absence_from is not null
--   and not exists (
--     select 1 from public.doctor_absences a
--     where a.doctor_id = d.id and coalesce(a.is_active, true)
--   );

-- 10) الحكم اليومي المحسوب بنفس منطق التطبيق (للتحقق من الجواب المتوقع لكل طبيب)
with today as (
  select
    (now() at time zone 'Asia/Baghdad')::date as d,
    case extract(dow from (now() at time zone 'Asia/Baghdad')::date)::int
      when 6 then 'السبت' when 0 then 'الأحد' when 1 then 'الاثنين'
      when 2 then 'الثلاثاء' when 3 then 'الأربعاء' when 4 then 'الخميس'
      when 5 then 'الجمعة'
    end as day_name
), base as (
  select
    d.id, d.doctor_name, d.booking_status, d.working_days, d.working_hours,
    d.absence_from, d.absence_to, t.day_name,
    substring(d.working_hours from (t.day_name || '\s*:?\s*([^،|]+)')) as today_chunk
  from public.doctors d cross join today t
)
select
  doctor_name,
  booking_status,
  day_name as today,
  today_chunk,
  case
    when absence_from is not null and absence_to is not null
         and left(absence_from::text, 10) <= to_char((select d from today), 'YYYY-MM-DD')
         and left(absence_to::text, 10)   >= to_char((select d from today), 'YYYY-MM-DD')
      then 'في إجازة'
    when coalesce(trim(working_hours), '') = '' and coalesce(trim(working_days), '') = ''
      then 'لا جدول (معلومة غير مؤكدة)'
    when today_chunk ~ '(عطل|اجاز|إجاز)' then 'عطلة اليوم'
    when today_chunk is null and coalesce(trim(working_hours), '') <> ''
      then 'اليوم غير مذكور في الجدول → لا دوام'
    when booking_status = 'available' then 'متواجد — الحجز متاح'
    when booking_status = 'full' then 'متواجد — الحجز مكتمل'
    when booking_status = 'walk_in_only' then 'متواجد — حضور مباشر فقط'
    when booking_status = 'unavailable' then 'غير متاح'
    else 'متواجد — حالة الحجز غير معروفة'
  end as computed_today
from base
order by doctor_name;

-- 11) بيانات «الأكثر طلبًا»: نقص/أصفار في أعمدة الطلب
select
  count(*) as doctors,
  count(*) filter (where profile_views is null) as views_null,
  count(*) filter (where coalesce(profile_views,0) + coalesce(call_taps,0) + coalesce(whatsapp_taps,0) = 0) as zero_demand
from public.doctors;

select doctor_name,
       coalesce(profile_views,0) as views, coalesce(call_taps,0) as calls, coalesce(whatsapp_taps,0) as wa,
       coalesce(profile_views,0) + 3*coalesce(call_taps,0) + 3*coalesce(whatsapp_taps,0) as demand_score
from public.doctors
order by demand_score desc
limit 10;
