import '../../search/arabic_text_utils.dart';
import 'health_subject_models.dart';

/// كشف حتمي عراقي/فصحى لعلاقة الشخص الخاضع للنقاش — بلا استدلال من الأسماء.
class HealthSubjectDetector {
  const HealthSubjectDetector();

  HealthSubjectDetection detect(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    if (n.isEmpty) return HealthSubjectDetection.none;

    final ret = _detectReturn(n);
    if (ret != null) return ret;

    final correction = _detectCorrection(n);
    if (correction != null) return correction;

    final relationship = _detectExplicitRelationship(n);
    if (relationship != null) return relationship;

    final self = _detectExplicitSelf(n);
    if (self != null) return self;

    // ضمير ثالث بلا مرجع معروف في النص → غموض، لا افتراض صاحب الحساب.
    if (_thirdPersonHealth(n)) {
      return const HealthSubjectDetection(
        type: HealthSubjectType.unknown,
        evidence: HealthSubjectEvidence.ambiguous,
      );
    }

    return HealthSubjectDetection.none;
  }

  /// استمرار سياقي: إجابة قصيرة/ضمير يتبع موضوعاً معروفاً دون تبديل صريح.
  bool looksLikeContinuation(String raw) {
    final n = ArabicTextUtils.normalize(raw);
    if (n.isEmpty) return false;
    if (detect(raw).isExplicitSwitchSignal) return false;
    // إجابات مدة/شدة قصيرة شائعة
    if (n.length <= 40 &&
        RegExp(
          r'(?:من\s+)?(?:ال)?بارح[ةه]?|اليوم|امبارح|قبل\s+يو|ساع|دقيق|خفيف|متوسط|شديد|اي\s*نعم|نعم|لا$|ماكو',
        ).hasMatch(n)) {
      return true;
    }
    if (RegExp(r'(?:عند[هها]|له|لها|صارله|صايرله)(?:\s|$)').hasMatch(n) &&
        _detectExplicitSelf(n) == null &&
        _detectExplicitRelationship(n) == null) {
      return true;
    }
    return false;
  }

  HealthSubjectDetection? _detectReturn(String n) {
    // نرجع لابني / نرجع لامي / ...
    final m = RegExp(
      r'(?:نرجع|ارجع|رجعنا)\s*(?:ل|الى|إلي|الي)?\s*'
      r'(ابني|بنيتي|بنتي|طفلي|طفلتي|ولدي|'
      r'امي|والدتي|'
      r'ابوي|ابويه|والدي|'
      r'زوجي|زوجتي|'
      r'اخي|اختي)',
    ).firstMatch(n);
    if (m == null) return null;
    final target = _tokenToType(m.group(1)!);
    return HealthSubjectDetection(
      type: target,
      evidence: HealthSubjectEvidence.explicitRelationship,
      returnToPrevious: true,
      returnTarget: target,
    );
  }

  HealthSubjectDetection? _detectCorrection(String n) {
    // لا مو إلي، لابني / مو الي لابني
    if (RegExp(
      r'(?:لا\s*)?(?:مو|مش)\s*(?:الي|إلي|اليّ|لالي|لإلي|انا|أنا).{0,12}'
      r'(?:ل)?(?:ابني|بنيتي|بنتي|طفلي|طفلتي|ولدي)',
    ).hasMatch(n)) {
      return const HealthSubjectDetection(
        type: HealthSubjectType.child,
        evidence: HealthSubjectEvidence.explicitRelationship,
        isChildHint: true,
      );
    }
    // لا مو لابني، إلي
    if (RegExp(
      r'(?:لا\s*)?(?:مو|مش)\s*(?:ل)?(?:ابني|بنيتي|بنتي|طفلي|طفلتي|ولدي).{0,12}'
      r'(?:الي|إلي|اليّ|لالي|لإلي|انا|أنا|عندي)',
    ).hasMatch(n)) {
      return const HealthSubjectDetection(
        type: HealthSubjectType.self,
        evidence: HealthSubjectEvidence.explicitSelf,
        isChildHint: false,
      );
    }
    return null;
  }

  HealthSubjectDetection? _detectExplicitRelationship(String n) {
    // ترتيب: علاقات أوضح أولاً
    if (RegExp(
      r'(?:^|[\s،,])(?:ابني|بنيتي|بنتي|طفلي|طفلتي|ولدي)(?:\s|$|[\s،,])|'
      r'(?:ل|عن)\s*(?:ابني|بنيتي|بنتي|طفلي|طفلتي|ولدي)',
    ).hasMatch(n)) {
      return HealthSubjectDetection(
        type: HealthSubjectType.child,
        evidence: HealthSubjectEvidence.explicitRelationship,
        isChildHint: true,
        ageYears: _extractAgeYears(n),
      );
    }
    if (RegExp(
      r'(?:^|[\s،,])(?:امي|والدتي)(?:\s|$|[\s،,])|'
      r'(?:ل|عن)\s*(?:امي|والدتي)|'
      // يمّه / يمه / يمي فقط مع سياق صحي قريب لتفادي التباس
      r'(?:يمه|يمّه|يمي)\s+(?:عندها|عندهاا|تعب|صداع|دوخ|الم|ألم|حرار)',
    ).hasMatch(n)) {
      return HealthSubjectDetection(
        type: HealthSubjectType.mother,
        evidence: HealthSubjectEvidence.explicitRelationship,
        isChildHint: false,
        ageYears: _extractAgeYears(n),
      );
    }
    if (RegExp(
      r'(?:^|[\s،,])(?:ابوي|ابويه|والدي)(?:\s|$|[\s،,])|'
      r'(?:ل|عن)\s*(?:ابوي|ابويه|والدي)',
    ).hasMatch(n)) {
      return HealthSubjectDetection(
        type: HealthSubjectType.father,
        evidence: HealthSubjectEvidence.explicitRelationship,
        isChildHint: false,
        ageYears: _extractAgeYears(n),
      );
    }
    if (RegExp(
      r'(?:^|[\s،,])(?:زوجي|زوجتي)(?:\s|$|[\s،,])|'
      r'(?:ل|عن)\s*(?:زوجي|زوجتي)',
    ).hasMatch(n)) {
      return HealthSubjectDetection(
        type: HealthSubjectType.spouse,
        evidence: HealthSubjectEvidence.explicitRelationship,
        isChildHint: false,
        ageYears: _extractAgeYears(n),
      );
    }
    if (RegExp(
      r'(?:^|[\s،,])(?:اخي|اختي|صديقي|صديقتي|قريبي|قريبتي)(?:\s|$|[\s،,])|'
      r'واحد\s+اعرف[هها]?',
    ).hasMatch(n)) {
      final family = RegExp(r'(?:اخي|اختي)').hasMatch(n);
      return HealthSubjectDetection(
        type: family
            ? HealthSubjectType.familyMember
            : HealthSubjectType.otherPerson,
        evidence: HealthSubjectEvidence.explicitRelationship,
        isChildHint: false,
        ageYears: _extractAgeYears(n),
      );
    }
    // تلميح طفل عام (بدون علاقة) — يبقى child hint للتوافق مع القواعد القديمة
    if (RegExp(
      r'(?:لطفل|للطفل|عمر[^\n]{0,8}(?:سنه|سنة|شهر))',
    ).hasMatch(n)) {
      return HealthSubjectDetection(
        type: HealthSubjectType.child,
        evidence: HealthSubjectEvidence.explicitRelationship,
        isChildHint: true,
        ageYears: _extractAgeYears(n),
      );
    }
    if (RegExp(r'(?:للكبار|للبالغ|انا بالغ|انا كبير)').hasMatch(n)) {
      return const HealthSubjectDetection(
        type: HealthSubjectType.self,
        evidence: HealthSubjectEvidence.explicitSelf,
        isChildHint: false,
      );
    }
    return null;
  }

  HealthSubjectDetection? _detectExplicitSelf(String n) {
    // وأنا عندي / انا هم عندي / عندي / احس / اعاني / صارلي / بيه
    if (RegExp(
      r'(?:^|[\sو،,])(?:انا|أنا)\s+(?:هم\s+)?(?:عندي|احس|أعاني|اعاني)|'
      r'(?:^|[\s،,])عندي(?:\s|$)|'
      r'(?:احس|أحس|اعاني|أعاني|صارلي|صايرلي|بيه|بيّه)(?:\s|$)|'
      r'عندي\s+(?:الم|ألم|صداع|حرار|دوخ|سعال|الم)',
    ).hasMatch(n)) {
      return HealthSubjectDetection(
        type: HealthSubjectType.self,
        evidence: HealthSubjectEvidence.explicitSelf,
        isChildHint: false,
        ageYears: _extractAgeYears(n),
      );
    }
    return null;
  }

  bool _thirdPersonHealth(String n) {
    return RegExp(
      r'(?:^|[\s،,])(?:عنده|عندها|يتعب|تتعب|يعاني|تعاني)(?:\s|$)',
    ).hasMatch(n);
  }

  int? _extractAgeYears(String n) {
    final m = RegExp(
      r'(?:عمر[هها]?|عمره|عمرها)\s*(\d{1,2})\s*(?:سنه|سنة|سنوات)?',
    ).firstMatch(n);
    if (m != null) {
      return int.tryParse(m.group(1)!);
    }
    final m2 = RegExp(r'(\d{1,2})\s*(?:سنه|سنة)').firstMatch(n);
    if (m2 != null) {
      final v = int.tryParse(m2.group(1)!);
      if (v != null && v <= 18) return v;
    }
    return null;
  }

  HealthSubjectType _tokenToType(String token) {
    switch (token) {
      case 'ابني':
      case 'بنيتي':
      case 'بنتي':
      case 'طفلي':
      case 'طفلتي':
      case 'ولدي':
        return HealthSubjectType.child;
      case 'امي':
      case 'والدتي':
        return HealthSubjectType.mother;
      case 'ابوي':
      case 'ابويه':
      case 'والدي':
        return HealthSubjectType.father;
      case 'زوجي':
      case 'زوجتي':
        return HealthSubjectType.spouse;
      case 'اخي':
      case 'اختي':
        return HealthSubjectType.familyMember;
      default:
        return HealthSubjectType.unknown;
    }
  }
}
