import '../pharmacies/pharmacy_models.dart';
import 'arabic_speech_numbers.dart';

/// نصوص قراءة صوتية محلية لصفحات الصيدلية / المستلزمات / العلاج الطبيعي.
class EntityProfileSpeech {
  EntityProfileSpeech._();

  /// قراءة باقات المكملات في صفحة الصيدلية (مثل باقات المختبر).
  static String pharmacyBundles({
    required String pharmacyName,
    required List<PharmacyBundle> bundles,
    int maxBundles = 8,
  }) {
    final buf = StringBuffer();
    final name = _clean(pharmacyName);
    if (name.isNotEmpty) {
      buf.write(name.startsWith('صيدلية') ? '$name. ' : 'صيدلية $name. ');
    }

    final visible = bundles.where((b) => b.isVisible).toList();
    if (visible.isEmpty) {
      buf.write('لا توجد باقات حالياً.');
      return _normalize(buf.toString());
    }

    buf.write(
      'يوجد ${ArabicSpeechNumbers.count(visible.length)} من الباقات. ',
    );

    final take = visible.take(maxBundles).toList();
    for (var i = 0; i < take.length; i++) {
      final b = take[i];
      final title = _clean(b.title);
      if (title.isEmpty) continue;
      buf.write('الباقة ${ArabicSpeechNumbers.ordinal(i + 1)}: $title. ');
      if (b.price > 0) {
        buf.write('سعرها ${ArabicSpeechNumbers.moneyIq(b.price)}. ');
      }
      final sub = _short(_clean(b.subtitle), maxChars: 90);
      if (sub.isNotEmpty) buf.write('$sub. ');
    }

    if (visible.length > maxBundles) {
      buf.write('وهناك المزيد داخل الصفحة.');
    }
    return _normalize(buf.toString());
  }

  /// نبذة صوتية لمحل مستلزمات أو مركز علاج طبيعي.
  static String placeProfile({
    required String name,
    required String kindLabel,
    String slogan = '',
    String description = '',
    String address = '',
    String openFrom = '',
    String openTo = '',
    bool? isOpenNow,
    List<String> tags = const [],
    int maxDescChars = 280,
  }) {
    final buf = StringBuffer();
    final n = _clean(name);
    if (n.isNotEmpty) {
      buf.write(n.startsWith(kindLabel) ? '$n. ' : '$kindLabel $n. ');
    }

    final slog = _clean(slogan);
    if (slog.isNotEmpty) buf.write('$slog. ');

    if (isOpenNow != null) {
      buf.write(isOpenNow ? 'مفتوح الآن. ' : 'مغلق الآن. ');
    }
    if (openFrom.trim().isNotEmpty && openTo.trim().isNotEmpty) {
      buf.write('ساعات العمل من $openFrom إلى $openTo. ');
    }

    final addr = _clean(address);
    if (addr.isNotEmpty) buf.write('العنوان: $addr. ');

    final desc = _short(_clean(description), maxChars: maxDescChars);
    if (desc.isNotEmpty) buf.write('$desc. ');

    final cleanTags = tags
        .map(_clean)
        .where((t) => t.isNotEmpty)
        .take(8)
        .toList();
    if (cleanTags.isNotEmpty) {
      buf.write('${cleanTags.join('، ')}. ');
    }

    return _normalize(buf.toString());
  }

  static String _short(String text, {required int maxChars}) {
    if (text.isEmpty) return '';
    if (text.length <= maxChars) return text;
    final cut = text.substring(0, maxChars);
    final lastStop = cut.lastIndexOf(RegExp(r'[.。!؟\n،]'));
    final body = (lastStop > 60 ? cut.substring(0, lastStop + 1) : cut).trim();
    if (body.endsWith('.') || body.endsWith('،') || body.endsWith('!')) {
      return body;
    }
    return '$body…';
  }

  static String _clean(String raw) {
    return raw
        .replaceAll(RegExp(r'[\u200e\u200f\u202a-\u202e]'), '')
        .replaceAll(RegExp(r'[#*_`~|<>{}[\]]'), ' ')
        .replaceAll(RegExp(r'https?:\/\/\S+', caseSensitive: false), ' ')
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
