/// تحويل أرقام إلى كلمات عربية مناسبة للقراءة الصوتية (TTS).
/// أسلوب قريب من الكلام اليومي بدون فواصل/أصفار رقمية تربك الجهاز.
class ArabicSpeechNumbers {
  ArabicSpeechNumbers._();

  static const _ones = <String>[
    'صفر',
    'واحد',
    'اثنان',
    'ثلاثة',
    'أربعة',
    'خمسة',
    'ستة',
    'سبعة',
    'ثمانية',
    'تسعة',
    'عشرة',
    'أحد عشر',
    'اثنا عشر',
    'ثلاثة عشر',
    'أربعة عشر',
    'خمسة عشر',
    'ستة عشر',
    'سبعة عشر',
    'ثمانية عشر',
    'تسعة عشر',
  ];

  static const _tens = <String>[
    '',
    '',
    'عشرون',
    'ثلاثون',
    'أربعون',
    'خمسون',
    'ستون',
    'سبعون',
    'ثمانون',
    'تسعون',
  ];

  static const _hundreds = <String>[
    '',
    'مائة',
    'مائتان',
    'ثلاثمائة',
    'أربعمائة',
    'خمسمائة',
    'ستمائة',
    'سبعمائة',
    'ثمانمائة',
    'تسعمائة',
  ];

  /// رقم صحيح غير سالب → كلمات (حتى ملايين).
  static String toWords(int value) {
    if (value < 0) return toWords(-value);
    if (value < 20) return _ones[value];
    if (value < 100) {
      final t = value ~/ 10;
      final o = value % 10;
      if (o == 0) return _tens[t];
      // كلام أوضح للـ TTS: خمسة وعشرين بدل خمسة وعشرون
      return '${_ones[o]} و${_tensSpoken(t)}';
    }
    if (value < 1000) {
      final h = value ~/ 100;
      final rest = value % 100;
      if (rest == 0) return _hundreds[h];
      return '${_hundreds[h]} و${toWords(rest)}';
    }
    if (value < 1000000) {
      final thousands = value ~/ 1000;
      final rest = value % 1000;
      final head = _thousandWords(thousands);
      if (rest == 0) return head;
      return '$head و${toWords(rest)}';
    }
    if (value < 1000000000) {
      final millions = value ~/ 1000000;
      final rest = value % 1000000;
      final head = _millionWords(millions);
      if (rest == 0) return head;
      return '$head و${toWords(rest)}';
    }
    // أرقام ضخمة نادرة: اقرأها مجزّأة آلافًا
    return value.toString();
  }

  static String _tensSpoken(int t) {
    // صيغة مسموعة أوضح مع «و» (خمسة وعشرين)
    const spoken = <String>[
      '',
      '',
      'عشرين',
      'ثلاثين',
      'أربعين',
      'خمسين',
      'ستين',
      'سبعين',
      'ثمانين',
      'تسعين',
    ];
    return spoken[t];
  }

  static String _thousandWords(int thousands) {
    if (thousands == 1) return 'ألف';
    if (thousands == 2) return 'ألفان';
    if (thousands >= 3 && thousands <= 10) {
      return '${toWords(thousands)} آلاف';
    }
    // عشرون/ثلاثون… ألف → عشرين/ثلاثين ألف (أوضح للـ TTS)
    if (thousands >= 20 && thousands < 100 && thousands % 10 == 0) {
      return '${_tensSpoken(thousands ~/ 10)} ألف';
    }
    return '${toWords(thousands)} ألف';
  }

  static String _millionWords(int millions) {
    if (millions == 1) return 'مليون';
    if (millions == 2) return 'مليونان';
    if (millions >= 3 && millions <= 10) {
      return '${toWords(millions)} ملايين';
    }
    return '${toWords(millions)} مليون';
  }

  /// سعر عراقي للقراءة: «خمسة وعشرين ألف دينار».
  static String moneyIq(int? value) {
    if (value == null || value <= 0) return '';
    return '${toWords(value)} دينار';
  }

  /// نسبة مئوية: «خمسة وعشرين بالمئة».
  static String percent(int? value) {
    if (value == null || value <= 0) return '';
    return '${toWords(value)} بالمئة';
  }

  /// عدد صغير للسياق: باقات / تحاليل.
  static String count(int value) => toWords(value);

  /// ترتيب الباقة: الأولى، الثانية، …
  static String ordinal(int index1Based) {
    const known = <String>[
      '',
      'الأولى',
      'الثانية',
      'الثالثة',
      'الرابعة',
      'الخامسة',
      'السادسة',
      'السابعة',
      'الثامنة',
      'التاسعة',
      'العاشرة',
    ];
    if (index1Based >= 1 && index1Based < known.length) {
      return known[index1Based];
    }
    return 'رقم ${toWords(index1Based)}';
  }
}
