/// ترتيب أيام الأسبوع للعرض والحفظ.
const doctorWeekDayOrder = <String>[
  'السبت',
  'الأحد',
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
];

/// يوم واحد في جدول التواجد: الاسم + الحالة (مساءً / عطلة / …).
typedef DoctorWeekDayEntry = ({String day, String status, bool isOff});

String? _periodLabelFromChunk(String chunk) {
  final n = chunk
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا');
  if (n.contains('عطل') || n.contains('اجاز') || n.contains('إجاز')) {
    return 'عطلة';
  }
  final hasMorning = n.contains('صباح');
  final hasEvening = n.contains('مساء');
  if (hasMorning && hasEvening) return 'صباحًا ومساءً';
  if (hasMorning) return 'صباحًا';
  if (hasEvening) return 'مساءً';
  return null;
}

/// يقرأ جدول الأسبوع من حقول الإدارة (متوافق مع الصيغ القديمة).
List<DoctorWeekDayEntry> parseDoctorWeekSchedule({
  required String workingDays,
  required String workingHours,
}) {
  final hours = workingHours.trim();
  final daysRaw = workingDays.trim();
  final parsed = <String, String>{};

  if (hours.isNotEmpty) {
    for (final day in doctorWeekDayOrder) {
      final match = RegExp(
        '$day\\s*:?\\s*([^،|]+)',
        unicode: true,
      ).firstMatch(hours);
      if (match == null) continue;
      final period = _periodLabelFromChunk(match.group(1) ?? '');
      if (period == null) continue;
      parsed[day] = period;
    }
  }

  if (parsed.isEmpty && daysRaw.isNotEmpty) {
    final allWeek = daysRaw.contains('كل أيام الأسبوع');
    for (final day in doctorWeekDayOrder) {
      if (allWeek || daysRaw.contains(day)) {
        parsed[day] = 'مساءً';
      }
    }
  }

  if (parsed.isEmpty) return const [];

  return [
    for (final day in doctorWeekDayOrder)
      if (parsed.containsKey(day))
        (
          day: day,
          status: parsed[day]!,
          isOff: parsed[day] == 'عطلة',
        ),
  ];
}

String doctorPeriodLabel(String value) {
  switch (value) {
    case 'morning':
      return 'صباحًا';
    case 'evening':
      return 'مساءً';
    case 'both':
      return 'صباحًا ومساءً';
    case 'off':
      return 'عطلة';
    default:
      return 'مساءً';
  }
}

/// يكتب أيام الدوام بصيغة قارئ البطاقة الحالي.
({String days, String hours}) formatDoctorWeek(Map<String, String> periods) {
  final active = <String>[];
  final lines = <String>[];
  for (final day in doctorWeekDayOrder) {
    final period = periods[day] ?? 'off';
    lines.add('$day ${doctorPeriodLabel(period)}');
    if (period != 'off') active.add(day);
  }
  final days = active.length == doctorWeekDayOrder.length
      ? 'كل أيام الأسبوع'
      : active.join('، ');
  return (days: days, hours: lines.join('، '));
}

/// قيم محرّر الأيام. ما لم يُقرأ من النص يبقى عطلة.
Map<String, String> doctorWeekEditorValues({
  required String workingDays,
  required String workingHours,
}) {
  final parsed = parseDoctorWeekSchedule(
    workingDays: workingDays,
    workingHours: workingHours,
  );
  final values = {for (final day in doctorWeekDayOrder) day: 'off'};
  for (final entry in parsed) {
    values[entry.day] = switch (entry.status) {
      'صباحًا' => 'morning',
      'مساءً' => 'evening',
      'صباحًا ومساءً' => 'both',
      _ => 'off',
    };
  }
  return values;
}
