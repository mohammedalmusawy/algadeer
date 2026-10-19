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

  // Phase 5C: صيغة «يومياً مساءً عدا الجمعة» — الأيام مو مكتوبة وحدة وحدة.
  final everyday = _parseEverydaySchedule(hours.isNotEmpty ? hours : daysRaw);
  if (everyday != null) return everyday;

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
        (day: day, status: parsed[day]!, isOff: parsed[day] == 'عطلة'),
  ];
}

/// توحيد الحروف حتى «يومياً / يوميا / كل الأيام» تنقرأ سوه.
String _normalizeScheduleText(String raw) => raw
    .replaceAll('أ', 'ا')
    .replaceAll('إ', 'ا')
    .replaceAll('آ', 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp('[\u064B-\u0652]'), '');

final _everydayPattern = RegExp(
  '(يومي|كل يوم|كل الايام|كل ايام|جميع الايام|طول الاسبوع|طوال الاسبوع)',
);
// «الا» بس ككلمة وحدها، حتى ما تنمسك من «الاثنين» و«الاسبوع».
final _exceptPattern = RegExp(
  '(ماعدا|ما عدا|عدا|باستثناء|(?:^|\\s)الا(?=\\s))',
);

/// «يومياً مساءً عدا الجمعة» ← ٦ أيام مساءً والجمعة عطلة.
/// «يومياً مساءً عدا الجمعة صباحاً» ← الجمعة صباحاً.
/// «يومياً مساءً، الجمعة صباحاً» ← الجمعة صباحاً والباقي مساءً.
/// يرجع null إذا النص مو بهالصيغة، فيكمل القارئ القديم مثل ما جان.
List<DoctorWeekDayEntry>? _parseEverydaySchedule(String raw) {
  if (raw.isEmpty) return null;
  final text = _normalizeScheduleText(raw);
  if (!_everydayPattern.hasMatch(text)) return null;

  final normDays = {
    for (final d in doctorWeekDayOrder) _normalizeScheduleText(d): d,
  };
  final exceptAt = _exceptPattern.firstMatch(text);
  // الجزء العام = قبل «عدا» وقبل أول اسم يوم.
  var generalEnd = exceptAt?.start ?? text.length;
  for (final key in normDays.keys) {
    final at = text.indexOf(key);
    if (at >= 0 && at < generalEnd) generalEnd = at;
  }
  final generalPeriod = _periodLabelFromChunk(text.substring(0, generalEnd));
  final rest = text.substring(generalEnd);
  // إذا الفترة مكتوبة بس بآخر الجملة («يومياً عدا الجمعة مساءً») فهي للكل.
  final base = generalPeriod ?? _periodLabelFromChunk(rest) ?? 'مساءً';

  final result = {for (final d in doctorWeekDayOrder) d: base};
  final chunks = text.split(RegExp('[،,|؛;]|\\s+و'));
  var offset = 0;
  for (final chunk in chunks) {
    final chunkAt = text.indexOf(chunk, offset);
    if (chunkAt >= 0) offset = chunkAt + chunk.length;
    for (final entry in normDays.entries) {
      final at = chunk.indexOf(entry.key);
      if (at < 0) continue;
      // اليوم بعد «عدا» = استثناء.
      final inExcept =
          exceptAt != null && chunkAt >= 0 && chunkAt + at > exceptAt.start;
      final own = _periodLabelFromChunk(chunk.substring(at + entry.key.length));
      if (inExcept) {
        result[entry.value] = (own != null && generalPeriod != null)
            ? own
            : 'عطلة';
      } else if (own != null) {
        result[entry.value] = own;
      }
    }
  }
  return [
    for (final d in doctorWeekDayOrder)
      (day: d, status: result[d]!, isOff: result[d] == 'عطلة'),
  ];
}

/// ملخص قصير للدوام: السطر الرئيسي + ملاحظات (عطلة / فترة مختلفة).
({String headline, List<String> notes, List<String> offDays})
summarizeDoctorWeek(List<DoctorWeekDayEntry> entries) {
  if (entries.isEmpty) {
    return (headline: '', notes: const [], offDays: const []);
  }
  final byDay = {for (final e in entries) e.day: e};
  final working = entries.where((e) => !e.isOff).toList();
  final offDays = [
    for (final d in doctorWeekDayOrder)
      if (byDay[d]?.isOff ?? false) d,
  ];
  if (working.isEmpty) {
    return (headline: 'عطلة', notes: const [], offDays: offDays);
  }
  // الفترة الأكثر تكراراً هي الأساس.
  final counts = <String, int>{};
  for (final e in working) {
    counts[e.status] = (counts[e.status] ?? 0) + 1;
  }
  final main = counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  final mainDays = [
    for (final d in doctorWeekDayOrder)
      if (byDay[d] != null && !byDay[d]!.isOff && byDay[d]!.status == main) d,
  ];
  final notes = <String>[
    for (final d in doctorWeekDayOrder)
      if (byDay[d] != null && !byDay[d]!.isOff && byDay[d]!.status != main)
        '$d ${byDay[d]!.status}',
  ];

  // أسبوع كامل معروف وأغلبه نفس الفترة ← «يومياً مساءً» والباقي ملاحظات.
  final fullWeek = entries.length == doctorWeekDayOrder.length;
  final headline = fullWeek && mainDays.length >= 4
      ? 'يومياً $main'
      : '${mainDays.join('، ')}: $main';
  return (headline: headline, notes: notes, offDays: offDays);
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
