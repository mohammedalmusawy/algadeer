import 'health_subject_detector.dart';
import 'health_subject_models.dart';

/// يقرر استمرار أو تبديل الموضوع الصحي دون دمج حقائق بين الأشخاص.
///
/// Chosen pending-question behavior (PC-0.3):
/// When an explicit subject switch is detected while a health question is
/// pending, the old subject flow is replaced (not merged). The new utterance
/// is NOT consumed as an answer to the previous subject's question.
///
/// Chosen return behavior:
/// «نرجع لابني» restores only the subject type when safely known; it does NOT
/// fabricate prior symptoms/duration/severity/safety facts.
class HealthSubjectCoordinator {
  HealthSubjectCoordinator({HealthSubjectDetector? detector})
      : _detector = detector ?? const HealthSubjectDetector();

  final HealthSubjectDetector _detector;
  int _keySeq = 0;

  HealthSubjectDetector get detector => _detector;

  HealthSubjectResolution resolve({
    required HealthSubjectContext? current,
    required String text,
    HealthSubjectType? previousType,
  }) {
    final detection = _detector.detect(text);
    final cur = current ?? HealthSubjectContext.unknown;

    if (detection.returnToPrevious) {
      final target = detection.returnTarget ?? detection.type;
      // لا نسترجع حقائق — موضوع جديد بنفس النوع فقط.
      final subject = _buildSubject(
        type: target,
        evidence: HealthSubjectEvidence.explicitRelationship,
        ageYears: detection.ageYears,
        isChildHint: detection.isChildHint ?? (target == HealthSubjectType.child),
      );
      return HealthSubjectResolution(
        subject: subject,
        switched: cur.type != target,
        returnRequested: true,
        previousType: cur.isKnown ? cur.type : previousType,
      );
    }

    if (detection.evidence == HealthSubjectEvidence.explicitSelf ||
        detection.evidence == HealthSubjectEvidence.explicitRelationship) {
      if (cur.isKnown && cur.type == detection.type) {
        return HealthSubjectResolution(
          subject: cur.copyWith(
            evidence: detection.evidence,
            ageYears: detection.ageYears ?? cur.ageYears,
            isChild: detection.isChildHint ?? cur.isChild,
            ageGroup: _ageGroupFor(
              detection.type,
              detection.isChildHint ?? cur.isChild,
            ),
          ),
          switched: false,
          previousType: previousType,
        );
      }
      // أول تأسيس صريح من unknown المحايد ≠ تبديل.
      // أي تغيير نوع (بما فيه unknown/ambiguous → معروف) = تبديل بلا دمج.
      final isNeutralStart = !cur.isKnown &&
          cur.evidence != HealthSubjectEvidence.ambiguous &&
          cur.sessionKey == HealthSubjectContext.unknown.sessionKey;
      final switched = !isNeutralStart && cur.type != detection.type;
      final subject = _buildSubject(
        type: detection.type,
        evidence: detection.evidence,
        ageYears: detection.ageYears,
        isChildHint: detection.isChildHint,
      );
      return HealthSubjectResolution(
        subject: subject,
        switched: switched,
        ambiguous: false,
        previousType: cur.isKnown ? cur.type : previousType,
      );
    }

    if (detection.evidence == HealthSubjectEvidence.ambiguous &&
        detection.type == HealthSubjectType.unknown) {
      // «عنده ألم» بلا مرجع — لا نفترض صاحب الحساب.
      if (!cur.isKnown) {
        return HealthSubjectResolution(
          subject: _buildSubject(
            type: HealthSubjectType.unknown,
            evidence: HealthSubjectEvidence.ambiguous,
          ),
          switched: false,
          ambiguous: true,
          previousType: previousType,
        );
      }
      // مرجع قائم: ضمير ثالث قد يكون استمراراً
      if (_detector.looksLikeContinuation(text)) {
        return HealthSubjectResolution(
          subject: cur.copyWith(
            evidence: HealthSubjectEvidence.contextualContinuation,
          ),
          switched: false,
          previousType: previousType,
        );
      }
      return HealthSubjectResolution(
        subject: cur,
        switched: false,
        ambiguous: true,
        previousType: previousType,
      );
    }

    // لا إشارة صريحة: استمرار سياقي إن وُجد موضوع معروف
    if (cur.isKnown) {
      return HealthSubjectResolution(
        subject: cur.copyWith(
          evidence: HealthSubjectEvidence.contextualContinuation,
        ),
        switched: false,
        previousType: previousType,
      );
    }

    // شكوى بصيغة المتكلم بلا علاقة → self عند أول ظهور صحي واضح
    final lateSelf = _detector.detect(text);
    if (lateSelf.evidence == HealthSubjectEvidence.explicitSelf) {
      return HealthSubjectResolution(
        subject: _buildSubject(
          type: HealthSubjectType.self,
          evidence: HealthSubjectEvidence.explicitSelf,
          ageYears: lateSelf.ageYears,
          isChildHint: false,
        ),
        switched: false,
      );
    }

    return HealthSubjectResolution(
      subject: cur.type == HealthSubjectType.unknown
          ? cur
          : HealthSubjectContext.unknown,
      switched: false,
      ambiguous: true,
      previousType: previousType,
    );
  }

  /// هل يجب استبدال الجلسة الصحية (لا دمج)؟
  bool shouldReplaceHealthState(HealthSubjectResolution resolution) {
    return resolution.switched || resolution.returnRequested;
  }

  HealthSubjectContext _buildSubject({
    required HealthSubjectType type,
    required HealthSubjectEvidence evidence,
    int? ageYears,
    bool? isChildHint,
  }) {
    _keySeq += 1;
    final isChild = isChildHint ??
        (type == HealthSubjectType.child
            ? true
            : (ageYears != null ? ageYears < 18 : null));
    return HealthSubjectContext(
      sessionKey: 'subj_${type.name}_$_keySeq',
      type: type,
      evidence: evidence,
      isChild: isChild,
      ageGroup: _ageGroupFor(type, isChild),
      ageYears: ageYears,
      reservedSexHint: null,
    );
  }

  String? _ageGroupFor(HealthSubjectType type, bool? isChild) {
    if (isChild == true || type == HealthSubjectType.child) return 'child';
    if (isChild == false) return 'adult';
    if (type == HealthSubjectType.mother ||
        type == HealthSubjectType.father ||
        type == HealthSubjectType.spouse ||
        type == HealthSubjectType.self) {
      return 'adult';
    }
    return null;
  }
}
