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

  /// يحاول استخراج أمر اتصال/واتساب من النص. null = بحث عادي.
  static VoiceContactCommand? tryParse(String raw) {
    final original = raw.trim();
    if (original.isEmpty) return null;

    final whatsapp = _tryParseWhatsApp(original);
    if (whatsapp != null) return whatsapp;

    return _tryParseCall(original);
  }

  static VoiceContactCommand? _tryParseCall(String original) {
    if (!_looksLikeCallVerb(original)) return null;

    final re = RegExp(
      r'^(?:أريد|اريد|ابي|أبغى|من\s+فضلك|لو\s+سمحت)?\s*'
      r'(?:اتصل|اتصال|كلّم|كلم|رن|رنّ|dial|call)\s*'
      r'(?:ب|على|ل|في|مع)?\s*(?:ال)?(?:دكتور|طبيب|مختبر)?\s*',
      caseSensitive: false,
    );
    final m = re.firstMatch(original);
    var target = m != null
        ? original.substring(m.end).trim()
        : original
            .replaceAll(
              RegExp(
                r'(?:أريد|اريد|ابي|اتصل|اتصال|كلّم|كلم|رن|رنّ|dial|call|ب|على|ل)',
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
    final q = original.toLowerCase();
    return q.contains('اتصل') ||
        q.contains('اتصال') ||
        RegExp(r'(^|\s)كلم(ني|ه|ها)?(\s|$)').hasMatch(q) ||
        q.contains('كلّم') ||
        RegExp(r'(^|\s)رنّ?(\s|$)').hasMatch(q) ||
        q.contains('call') ||
        q.contains('dial');
  }

  static VoiceContactCommand? _tryParseWhatsApp(String original) {
    final qLower = original.toLowerCase();
    final hasWa = qLower.contains('واتس') ||
        qLower.contains('whatsapp') ||
        qLower.contains('واتساب');
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

    // أولاً: بقايا «ل» من «للدكتور» بعد مطابقة حرف الجر في النمط.
    s = s.replaceFirst(RegExp(r'^ل(?=دكتور|طبيب|دكتورة|طبيبة)'), '').trim();
    if (_isRoleOnlyToken(s)) return '';

    // ترتيب فقط: للثاني / على الاول → هدف سياقي فارغ.
    final withoutParticle = s.replaceFirst(RegExp(r'^(?:ل|ب|على)'), '').trim();
    if (_isOrdinalOnlyToken(withoutParticle) || _isOrdinalOnlyToken(s)) {
      return '';
    }

    s = s
        .replaceFirst(
          RegExp(
            r'^(?:ال)?(?:دكتور|الدكتور|دكتورة|الدكتورة|طبيب|الطبيب|طبيبة|الطبيبة|مختبر|المختبر)\s+',
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
      r'^(?:ال)?(?:دكتور|دكتورة|طبيب|طبيبة|مختبر)$',
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
