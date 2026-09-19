import 'package:flutter/foundation.dart';

/// نموذج ترحيب موحّد للواجهة والنطق — مصدر واحد للاسم والنصوص.
class PersonalizedGreeting {
  const PersonalizedGreeting({
    required this.displayGreeting,
    required this.subtitle,
    required this.spokenGreeting,
    this.firstName,
  });

  final String displayGreeting;
  final String subtitle;
  final String spokenGreeting;

  /// اسم صالح للترحيب، أو null إن لم يوجد.
  final String? firstName;

  static const String subtitleText = 'كيف يمكنني مساعدتك؟';

  static const String _spokenNoName =
      'مرحباً بك في تطبيق الغدير، كيف يمكنني مساعدتك اليوم؟';

  /// يبني الترحيب من الاسم السلطوي (PC-1.1 preferredName عبر
  /// [UserProfileService.getDisplayName]).
  factory PersonalizedGreeting.fromDisplayName(String? rawName) {
    final name = sanitizeGreetingName(rawName);
    if (name == null) {
      return const PersonalizedGreeting(
        displayGreeting: 'مرحباً بك 👋',
        subtitle: subtitleText,
        spokenGreeting: _spokenNoName,
      );
    }
    return PersonalizedGreeting(
      displayGreeting: 'مرحباً بك، $name 👋',
      subtitle: subtitleText,
      spokenGreeting:
          'مرحباً بك $name في تطبيق الغدير، كيف يمكنني مساعدتك اليوم؟',
      firstName: name,
    );
  }
}

/// يرفض null/فارغ/بريد/هاتف/قيم وهمية — لا تُعرض ولا تُنطق.
String? sanitizeGreetingName(String? raw) {
  final n = raw?.trim() ?? '';
  if (n.isEmpty) return null;
  if (n.toLowerCase() == 'null') return null;
  if (n.contains('@')) return null;

  final digitsOnly = n.replaceAll(RegExp(r'[\s+\-().]'), '');
  if (digitsOnly.length >= 7 && RegExp(r'^\d+$').hasMatch(digitsOnly)) {
    return null;
  }

  const placeholders = {
    'user',
    'guest',
    'username',
    'test',
    'unknown',
    'اسم',
    'بدون اسم',
  };
  if (placeholders.contains(n.toLowerCase())) return null;

  return n;
}

/// حارس ترحيب الإطلاق مرة واحدة لكل عملية تشغيل (ذاكرة فقط).
class StartupGreeting {
  StartupGreeting._();

  /// حارس على مستوى العملية فقط — لا SharedPreferences.
  static bool _spokenThisProcess = false;

  static bool get hasSpokenThisLaunch => _spokenThisProcess;

  /// للاختبارات فقط.
  @visibleForTesting
  static void resetForTest() {
    _spokenThisProcess = false;
  }

  /// يحجز فتحة الترحيب لهذه العملية. أول منجح فقط.
  static bool tryClaimGreetingSlot() {
    if (_spokenThisProcess) return false;
    _spokenThisProcess = true;
    return true;
  }
}
