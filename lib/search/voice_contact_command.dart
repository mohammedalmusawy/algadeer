import 'arabic_text_utils.dart';

/// أوامر صوتية/نصية للاتصال وواتساب من البحث الذكي.
enum VoiceContactKind { call, whatsapp }

class VoiceContactCommand {
  const VoiceContactCommand({
    required this.kind,
    required this.targetQuery,
    this.message = '',
    required this.rawQuery,
  });

  final VoiceContactKind kind;
  final String targetQuery;
  final String message;
  final String rawQuery;

  bool get hasTarget => targetQuery.trim().isNotEmpty;

  /// أخطاء إملائية شائعة + إنجليزي: وتساب، مارسل، whatsapp…
  /// عام لأي طبيب/مختبر — بلا أسماء ثابتة.
  static String canonicalizeAliases(String raw) {
    var s = raw;
    s = s.replaceAll(
      RegExp(r'وتساب|ووتساب|واتسب|واتس\s*اب', caseSensitive: false),
      'واتساب',
    );
    s = s.replaceAll(
      RegExp(r'\bwatsapp\b|\bwhatsap\b|\bwhats\s*app\b', caseSensitive: false),
      'whatsapp',
    );
    // «مارسل» شائعة بدل «راسل» بالصوت/الكتابة السريعة.
    s = s.replaceAll(RegExp(r'مارسل', caseSensitive: false), 'راسل');
    return s;
  }

  /// يحاول استخراج أمر اتصال/واتساب من النص. null = بحث عادي.
  static VoiceContactCommand? tryParse(String raw) {
    final original = raw.trim();
    if (original.isEmpty) return null;

    final canonical = canonicalizeAliases(original);
    final whatsapp = _tryParseWhatsApp(canonical);
    if (whatsapp != null) {
      return VoiceContactCommand(
        kind: whatsapp.kind,
        targetQuery: whatsapp.targetQuery,
        message: whatsapp.message,
        rawQuery: original,
      );
    }

    final call = _tryParseCall(canonical);
    if (call == null) return null;
    return VoiceContactCommand(
      kind: call.kind,
      targetQuery: call.targetQuery,
      message: call.message,
      rawQuery: original,
    );
  }

  static VoiceContactCommand? _tryParseCall(String original) {
    if (!_looksLikeCallVerb(original)) return null;

    // طبّع الهمزات حتى يطابق ^(?:اتصل) صيغ STT «أتصل/إتصل».
    // بعد normalize: «على» → «علي»، فيجب قبول «علي» كحرف جر قبل اللقب
    // وإلا يبقى «علي دكتور علي …» ويُفسَّر كاسم مزدوج.
    final forMatch = ArabicTextUtils.normalize(original);
    final re = RegExp(
      r'^(?:أريد|اريد|ابي|أبغى|من\s+فضلك|لو\s+سمحت)?\s*'
      r'(?:اتصل|اتصال|كل[مّ]|كلم|رن|رنّ|dial|call)\s*'
      r'(?:ب|على|علي|ل|في|مع)?\s*(?:ال)?(?:دكتور|طبيب|مختبر|اشعه|اشعة|أشعة)?\s*',
      caseSensitive: false,
    );
    final m = re.firstMatch(forMatch);
    var target = m != null
        ? forMatch.substring(m.end).trim()
        : forMatch
            .replaceAll(
              RegExp(
                r'(?:أريد|اريد|ابي|اتصل|اتصال|كل[مّ]|كلم|رن|رنّ|dial|call|ب|على|علي|ل)',
                caseSensitive: false,
              ),
              ' ',
            )
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    target = _stripLeadingParticles(target);
    target = _stripTrailingPolite(target);

    return VoiceContactCommand(
      kind: VoiceContactKind.call,
      targetQuery: target,
      rawQuery: original,
    );
  }

  static bool _looksLikeCallVerb(String original) {
    final q = ArabicTextUtils.normalize(original);
    return q.contains('اتصل') ||
        q.contains('اتصال') ||
        RegExp(r'(^|\s)كلم(ني|ه|ها)?(\s|$)').hasMatch(q) ||
        q.contains('كلم') ||
        RegExp(r'(^|\s)رنّ?(\s|$)').hasMatch(q) ||
        q.contains('call') ||
        q.contains('dial');
  }

  static VoiceContactCommand? _tryParseWhatsApp(String original) {
    final qNorm = ArabicTextUtils.normalize(original);
    final qLower = original.toLowerCase();
    final hasWa = qNorm.contains('واتس') ||
        qNorm.contains('واتساب') ||
        qLower.contains('whatsapp') ||
        qNorm.contains('وتساب');
    if (!hasWa) return null;

    String target = original;
    var message = '';

    final withMessage = RegExp(
      r'^(?:أريد|اريد|ابي|أبغى|من\s+فضلك|لو\s+سمحت)?\s*'
      r'(?:أرسل|ارسل|راسل|ابعث|إرسال)?\s*'
      r'(?:رسالة\s*)?(?:واتساب|واتس\s*اب|واتس|whatsapp)\s*'
      r'(?:رسالة\s*)?(?:إلى|الى|ل|على|ب)?\s*',
      caseSensitive: false,
    ).firstMatch(original);

    if (withMessage != null) {
      target = original.substring(withMessage.end).trim();
    } else {
      target = original
          .replaceAll(
            RegExp(
              r'(?:أريد|اريد|ابي|أرسل|ارسل|راسل|دزله|دزّله|دزوله|دز|رسالة|واتساب|واتس\s*اب|واتس|whatsapp|إلى|الى)',
              caseSensitive: false,
            ),
            ' ',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    final split = RegExp(
      r'^(.*?)(?:\s*[:：]\s*|\s+(?:وقل(?:ه|ها)?|ورسالة|رسالة)\s+)(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(target);
    if (split != null) {
      target = (split.group(1) ?? '').trim();
      message = (split.group(2) ?? '').trim();
    }

    target = _stripLeadingParticles(target);
    target = _stripTrailingPolite(target);

    return VoiceContactCommand(
      kind: VoiceContactKind.whatsapp,
      targetQuery: target,
      message: message,
      rawQuery: original,
    );
  }

  static String _stripLeadingParticles(String input) {
    var s = input.trim();
    // لقب مهني وحده = إشارة سياقية وليست اسماً.
    if (_isRoleOnlyToken(s)) return '';

    // أولاً: بقايا «ل/لل» من «للدكتور/لمختبر/للأشعة».
    s = s.replaceFirst(
      RegExp(r'^ل{1,2}(?=دكتور|طبيب|دكتورة|طبيبة|مختبر|اشعه|اشعة|أشعة)'),
      '',
    ).trim();
    if (_isRoleOnlyToken(s)) return '';

    // ترتيب فقط: للثاني / على الاول / علي الاول (بعد تطبيع) → هدف سياقي فارغ.
    final withoutParticle =
        s.replaceFirst(RegExp(r'^(?:ل|ب|على|علي)'), '').trim();
    if (_isOrdinalOnlyToken(withoutParticle) || _isOrdinalOnlyToken(s)) {
      return '';
    }

    // «علي دكتور …» من تطبيع «على دكتور …» — أزل حرف الجر قبل اللقب.
    s = s
        .replaceFirst(
          RegExp(
            r'^(?:ب|ل|على|علي)\s+(?=ال?(?:دكتور|دكتورة|طبيب|طبيبة|مختبر|اشعه|اشعة|أشعة))',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    s = s
        .replaceFirst(
          RegExp(
            r'^(?:ال)?(?:دكتور|الدكتور|دكتورة|الدكتورة|طبيب|الطبيب|طبيبة|الطبيبة|مختبر|المختبر|اشعه|اشعة|أشعة|الاشعه|الأشعة)\s+',
            caseSensitive: false,
          ),
          '',
        )
        .replaceFirst(RegExp(r'^[بفل]\s+'), '')
        .trim();

    if (_isRoleOnlyToken(s) || _isOrdinalOnlyToken(s)) return '';
    return s;
  }

  /// الدكتور / الطبيب / دكتور… بدون اسم حقيقي.
  static bool _isRoleOnlyToken(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return true;
    return RegExp(
      r'^(?:ال)?(?:دكتور|دكتورة|طبيب|طبيبة|مختبر|اشعه|اشعة|أشعة)$',
      caseSensitive: false,
    ).hasMatch(t);
  }

  static bool _isOrdinalOnlyToken(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return false;
    return RegExp(
      r'^(?:ال)?(?:اول|أول|ثاني|ثالث|رابع|خامس|اخير|أخير)(?:\s*واحد)?$',
      caseSensitive: false,
    ).hasMatch(t);
  }

  static String _stripTrailingPolite(String input) {
    return input
        .replaceAll(
          RegExp(
            r'\s+(?:من فضلك|لو سمحت|رجاء|رجاءً|حالًا|حاليا|الآن|الان)\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }
}
