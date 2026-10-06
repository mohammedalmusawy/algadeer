import 'patient_health_models.dart';

/// يحوّل الأرقام العربية والفارسية إلى أرقام غربية.
String normalizeArabicDigits(String input) {
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final easternIndex = eastern.indexOf(ch);
    if (easternIndex >= 0) {
      buffer.write(easternIndex);
      continue;
    }
    final persianIndex = persian.indexOf(ch);
    if (persianIndex >= 0) {
      buffer.write(persianIndex);
      continue;
    }
    buffer.write(ch);
  }
  return buffer.toString();
}

String normalizeHealthNumber(String input) {
  var text = normalizeArabicDigits(input).trim();
  text = text.replaceAll('٬', '').replaceAll(' ', '');
  text = text.replaceAll('٫', '.').replaceAll(',', '.');
  return text;
}

int? parseHealthInt(String input) {
  final text = normalizeHealthNumber(input);
  if (text.isEmpty || text.contains('.')) return null;
  return int.tryParse(text);
}

double? parseHealthDouble(String input) {
  final text = normalizeHealthNumber(input);
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

DateTime? parseHealthStamp(String input, {DateTime? fallback}) {
  final text = normalizeArabicDigits(input).trim();
  if (text.isEmpty) return fallback;
  final match = RegExp(
    r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:[ T](\d{1,2}):(\d{2}))?$',
  ).firstMatch(text);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4) ?? '0');
  final minute = int.parse(match.group(5) ?? '0');
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  if (hour > 23 || minute > 59) return null;
  final stamp = DateTime(year, month, day, hour, minute);
  if (stamp.month != month || stamp.day != day) return null;
  return stamp;
}

/// فحص شكل القيمة والتاريخ فقط. بلا أهداف طبية وبلا تنبيه تشخيصي.
String? validateMeasuredAt(DateTime measuredAt, DateTime now) {
  if (measuredAt.isBefore(DateTime(1950))) {
    return 'التاريخ بعيد. تأكد من السنة.';
  }
  if (measuredAt.isAfter(now.add(const Duration(minutes: 2)))) {
    return 'التاريخ والوقت ما يكونان بالمستقبل.';
  }
  return null;
}

String? validateBloodPressure({
  required String systolic,
  required String diastolic,
  String pulse = '',
  required DateTime measuredAt,
  required DateTime now,
}) {
  final sys = parseHealthInt(systolic);
  final dia = parseHealthInt(diastolic);
  if (sys == null || dia == null) {
    return 'اكتب الانقباضي والانبساطي أرقاماً.';
  }
  if (sys < 40 || sys > 300 || dia < 20 || dia > 200) {
    return 'القيمة خارج حدود التسجيل.';
  }
  if (sys <= dia) {
    return 'الانقباضي لازم يكون أعلى من الانبساطي.';
  }
  if (pulse.trim().isNotEmpty) {
    final beat = parseHealthInt(pulse);
    if (beat == null || beat < 20 || beat > 250) {
      return 'النبض، إن كتبته، لازم يكون رقماً ضمن حدود التسجيل.';
    }
  }
  return validateMeasuredAt(measuredAt, now);
}

String? validateGlucose({
  required String value,
  required GlucoseUnit unit,
  required DateTime measuredAt,
  required DateTime now,
}) {
  final number = parseHealthDouble(value);
  if (number == null) return 'اكتب قيمة السكر رقماً.';
  final low = unit == GlucoseUnit.mgDl ? 10 : 0.5;
  final high = unit == GlucoseUnit.mgDl ? 900 : 50;
  if (number < low || number > high) {
    return 'القيمة خارج حدود التسجيل لهذه الوحدة.';
  }
  return validateMeasuredAt(measuredAt, now);
}

String? validateConditionLabel(ConditionKind kind, String label) {
  if (kind == ConditionKind.other && label.trim().isEmpty) {
    return 'اكتب اسم المرض المزمن الآخر.';
  }
  return null;
}

String? validateEventTitle(String title) {
  if (title.trim().isEmpty) return 'اكتب عنوان السجل.';
  return null;
}

bool healthStampInPeriod(DateTime stamp, FollowUpSelection selection) {
  final start = selection.periodStart;
  if (stamp.isAfter(selection.issuedAt.add(const Duration(minutes: 1)))) {
    return false;
  }
  if (start == null) return true;
  return !stamp.isBefore(start);
}
