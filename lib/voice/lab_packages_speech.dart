import '../models/lab_models.dart';
import 'arabic_speech_numbers.dart';

/// نصوص قراءة صوتية محلية لباقات/عروض المختبر — بدون سحابة.
/// الأرقام تُحوَّل إلى كلمات عربية حتى لا يقرأ الجهاز الفواصل والأصفار حرفًا حرفًا.
class LabPackagesSpeech {
  LabPackagesSpeech._();

  static String build({
    required String labName,
    required List<LabPackageItem> packages,
    bool offersOnly = false,
    int maxPackages = 8,
  }) {
    final name = labName.trim();
    final kind = offersOnly ? 'العروض' : 'الباقات';
    final kindOne = offersOnly ? 'العرض' : 'الباقة';
    final buf = StringBuffer();

    if (name.isNotEmpty) {
      buf.write('${_spokenLabName(name)}. ');
    }

    if (packages.isEmpty) {
      buf.write(offersOnly ? 'لا توجد عروض حالياً.' : 'لا توجد باقات حالياً.');
      return _normalize(buf.toString());
    }

    buf.write('يوجد ${ArabicSpeechNumbers.count(packages.length)} من $kind. ');

    final take = packages.take(maxPackages).toList();
    for (var i = 0; i < take.length; i++) {
      final p = take[i];
      final pName = _cleanSpoken(p.name);
      if (pName.isEmpty) continue;

      buf.write('$kindOne ${ArabicSpeechNumbers.ordinal(i + 1)}: $pName. ');
      buf.write(_priceClause(p));

      // في قائمة الباقات: وصف قصير جدًا فقط — التفاصيل في صفحة الباقة.
      final desc = _shortDescription(p.description, maxChars: 90);
      if (desc.isNotEmpty) {
        buf.write('$desc. ');
      }

      final testsCount = _testsCount(p);
      if (testsCount > 0) {
        buf.write(
          'تشمل ${ArabicSpeechNumbers.count(testsCount)} ${_analysisNoun(testsCount)}. ',
        );
      }
    }

    if (packages.length > maxPackages) {
      buf.write('وهناك المزيد داخل الصفحة.');
    }

    return _normalize(buf.toString());
  }

  /// قراءة باقة واحدة بتفاصيل أوضح (صفحة تفاصيل الباقة).
  static String buildOne(
    LabPackageItem package, {
    String labName = '',
    int maxAnalyses = 12,
  }) {
    final buf = StringBuffer();
    final name = labName.trim();
    if (name.isNotEmpty) {
      buf.write('${_spokenLabName(name)}. ');
    }

    final pName = _cleanSpoken(package.name);
    if (pName.isEmpty) {
      buf.write('لا توجد تفاصيل لهذه الباقة.');
      return _normalize(buf.toString());
    }

    final kindOne = package.hasOldPrice ? 'العرض' : 'الباقة';
    buf.write('$kindOne: $pName. ');
    buf.write(_priceClause(package));

    final desc = _shortDescription(package.description, maxChars: 180);
    if (desc.isNotEmpty) {
      buf.write('$desc. ');
    }

    final analysisNames = _analysisNames(package);
    if (analysisNames.isNotEmpty) {
      final take = analysisNames.take(maxAnalyses).toList();
      buf.write(
        'التحاليل المشمولة عددها ${ArabicSpeechNumbers.count(analysisNames.length)}. ',
      );
      buf.write('${take.join('، ')}. ');
      if (analysisNames.length > maxAnalyses) {
        buf.write('وهناك المزيد داخل الصفحة.');
      }
    } else {
      final testsCount = package.analysesCount;
      if (testsCount > 0) {
        buf.write(
          'تشمل ${ArabicSpeechNumbers.count(testsCount)} ${_analysisNoun(testsCount)}. ',
        );
      }
    }

    return _normalize(buf.toString());
  }

  static String _priceClause(LabPackageItem p) {
    final price = p.newPrice;
    final old = p.oldPrice;
    if (price == null || price <= 0) return '';

    final newMoney = ArabicSpeechNumbers.moneyIq(price);
    if (p.hasOldPrice && old != null && old > 0) {
      final oldMoney = ArabicSpeechNumbers.moneyIq(old);
      final discount = p.discountPercent;
      final discountPart = (discount != null && discount > 0)
          ? ' بخصم ${ArabicSpeechNumbers.percent(discount)}.'
          : '.';
      return 'سعرها $newMoney بدل $oldMoney$discountPart ';
    }
    return 'سعرها $newMoney. ';
  }

  static String _spokenLabName(String name) {
    return name.startsWith('مختبر') ? name : 'مختبر $name';
  }

  static int _testsCount(LabPackageItem p) {
    if (p.analysesCount > 0) return p.analysesCount;
    if (p.testNames.isNotEmpty) return p.testNames.length;
    return p.analyses.length;
  }

  static List<String> _analysisNames(LabPackageItem package) {
    final names = <String>[];
    for (final a in package.analyses) {
      final n = a.arabicDisplayName.trim().isNotEmpty
          ? a.arabicDisplayName.trim()
          : a.name.trim();
      final cleaned = _cleanSpoken(n);
      if (cleaned.isNotEmpty) names.add(cleaned);
    }
    if (names.isEmpty) {
      for (final n in package.testNames) {
        final cleaned = _cleanSpoken(n);
        if (cleaned.isNotEmpty) names.add(cleaned);
      }
    }
    return names;
  }

  static String _analysisNoun(int count) {
    if (count == 1) return 'تحليلًا';
    if (count == 2) return 'تحليلين';
    if (count >= 3 && count <= 10) return 'تحاليل';
    return 'تحليلًا';
  }

  static String _shortDescription(String raw, {required int maxChars}) {
    var text = _cleanSpoken(raw);
    if (text.isEmpty) return '';
    // إزالة روابط وأرقام خام طويلة داخل الوصف حتى لا تُقرأ حرفًا حرفًا
    text = text
        .replaceAll(RegExp(r'https?:\/\/\S+', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'www\.\S+', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b\d{4,}\b'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars).trim()}…';
  }

  static String _cleanSpoken(String raw) {
    return raw
        .replaceAll(RegExp(r'[\u200e\u200f\u202a-\u202e]'), '')
        .replaceAll(RegExp(r'[#*_`~|<>{}[\]]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalize(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s+([.،])'), r'$1')
        .replaceAll(RegExp(r'([.،]){2,}'), r'$1')
        .trim();
  }
}
