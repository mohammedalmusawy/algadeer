import 'clarification_models.dart';

/// بنّاء ردود التوضيح العربية — مصدر واحد للجمل (نص/صوت).
class ClarificationResponseBuilder {
  const ClarificationResponseBuilder();

  String build(PendingClarification pending, {String? customLead}) {
    if (pending.candidates.isEmpty) {
      return 'أي خيار تقصد؟ وضّح أكثر من فضلك.';
    }
    if (pending.candidates.length == 1) {
      final c = pending.candidates.first;
      final secondary = (c.secondaryLabel ?? '').trim();
      if (secondary.isEmpty) {
        return 'تقصد ${c.primaryLabel}؟';
      }
      return 'تقصد ${c.primaryLabel} — $secondary؟';
    }

    if (pending.entityType == ClarificationEntityType.doctor) {
      return _buildDoctor(pending, customLead: customLead);
    }
    if (pending.entityType == ClarificationEntityType.laboratory) {
      return _buildLaboratory(pending, customLead: customLead);
    }
    if (pending.entityType == ClarificationEntityType.analysis) {
      return _buildAnalysis(pending, customLead: customLead);
    }
    if (pending.entityType == ClarificationEntityType.package ||
        pending.entityType == ClarificationEntityType.offer) {
      return _buildPackage(pending, customLead: customLead);
    }

    // قالب عام لكيانات مستقبلية.
    return _buildNumbered(pending, lead: customLead ?? 'وجدت أكثر من نتيجة:');
  }

  String invalidOrdinal(PendingClarification pending) {
    final n = pending.candidates.length;
    if (n == 2) {
      return 'عندي خياران فقط. تقصد الأول أم الثاني؟';
    }
    return 'الرقم خارج النطاق. اختر من 1 إلى $n.';
  }

  String stillAmbiguous(PendingClarification pending) {
    if (pending.candidates.length == 2) {
      if (pending.entityType == ClarificationEntityType.laboratory) {
        return 'ما زال غير واضح. ${_buildLaboratory(pending)}';
      }
      if (pending.entityType == ClarificationEntityType.analysis) {
        return 'ما زال غير واضح. ${_buildAnalysis(pending)}';
      }
      if (pending.entityType == ClarificationEntityType.package ||
          pending.entityType == ClarificationEntityType.offer) {
        return 'ما زال غير واضح. ${_buildPackage(pending)}';
      }
      return 'ما زال غير واضح. ${_buildDoctor(pending)}';
    }
    return 'ما زال غير واضح. أي رقم تقصد من القائمة؟';
  }

  String unsafeYesNo(PendingClarification pending) {
    if (pending.entityType == ClarificationEntityType.laboratory) {
      return 'حدّد أي مختبر تقصد: الأول أو الثاني، أو اذكر الاسم/الموقع.';
    }
    if (pending.entityType == ClarificationEntityType.analysis) {
      return 'حدّد أي تحليل تقصد: الأول أو الثاني، أو اذكر الاسم/الاختصار.';
    }
    if (pending.entityType == ClarificationEntityType.package ||
        pending.entityType == ClarificationEntityType.offer) {
      return 'حدّد أي باقة تقصد: الأولى أو الثانية، أو اذكر الاسم/المختبر.';
    }
    return 'حدّد أي خيار تقصد: الأول أو الثاني، أو اذكر الاسم/الاختصاص.';
  }

  String _buildPackage(PendingClarification pending, {String? customLead}) {
    final cs = pending.candidates;
    if (cs.length == 2) {
      final a = cs[0];
      final b = cs[1];
      final aSec = (a.secondaryLabel ?? '').trim();
      final bSec = (b.secondaryLabel ?? '').trim();
      final lead = customLead ?? 'وجدت أكثر من باقة مطابقة.';
      final aPart =
          aSec.isEmpty ? a.primaryLabel : '${a.primaryLabel} — $aSec';
      final bPart =
          bSec.isEmpty ? b.primaryLabel : '${b.primaryLabel} — $bSec';
      return '$lead أي واحدة تقصد؟ $aPart، أم $bPart؟';
    }
    return _buildNumbered(
      pending,
      lead: customLead ?? 'وجدت أكثر من باقة مطابقة:',
    );
  }

  String _buildAnalysis(PendingClarification pending, {String? customLead}) {
    final cs = pending.candidates;
    if (cs.length == 2) {
      final a = cs[0];
      final b = cs[1];
      final aSec = (a.secondaryLabel ?? '').trim();
      final bSec = (b.secondaryLabel ?? '').trim();
      final lead = customLead ?? 'وجدت أكثر من تحليل مطابق.';
      final aPart =
          aSec.isEmpty ? a.primaryLabel : '${a.primaryLabel} ($aSec)';
      final bPart =
          bSec.isEmpty ? b.primaryLabel : '${b.primaryLabel} ($bSec)';
      return '$lead أي واحد تقصد؟ $aPart، أم $bPart؟';
    }
    return _buildNumbered(
      pending,
      lead: customLead ?? 'وجدت أكثر من تحليل مطابق:',
    );
  }

  String _buildLaboratory(PendingClarification pending, {String? customLead}) {
    final cs = pending.candidates;
    if (cs.length == 2) {
      final a = cs[0];
      final b = cs[1];
      final aSec = (a.secondaryLabel ?? '').trim();
      final bSec = (b.secondaryLabel ?? '').trim();
      final lead = customLead ?? 'وجدت أكثر من مختبر مطابق.';
      final aPart =
          aSec.isEmpty ? a.primaryLabel : '${a.primaryLabel} — $aSec';
      final bPart =
          bSec.isEmpty ? b.primaryLabel : '${b.primaryLabel} — $bSec';
      return '$lead أي واحد تقصد؟ $aPart، أم $bPart؟';
    }
    return _buildNumbered(
      pending,
      lead: customLead ?? 'وجدت أكثر من مختبر مطابق:',
    );
  }

  String _buildDoctor(PendingClarification pending, {String? customLead}) {
    final cs = pending.candidates;
    if (cs.length == 2) {
      final a = cs[0];
      final b = cs[1];
      final aSec = (a.secondaryLabel ?? '').trim();
      final bSec = (b.secondaryLabel ?? '').trim();
      final lead = customLead ?? 'وجدت أكثر من طبيب مطابق.';
      final aPart = aSec.isEmpty
          ? a.primaryLabel
          : '${a.primaryLabel}، اختصاص $aSec';
      final bPart = bSec.isEmpty
          ? b.primaryLabel
          : '${b.primaryLabel}، اختصاص $bSec';
      return '$lead تقصد $aPart، أم $bPart؟';
    }
    return _buildNumbered(
      pending,
      lead: customLead ?? 'وجدت أكثر من نتيجة:',
    );
  }

  String _buildNumbered(PendingClarification pending, {required String lead}) {
    final buf = StringBuffer(lead);
    buf.write('\n');
    final take = pending.candidates.take(5).toList();
    for (var i = 0; i < take.length; i++) {
      final c = take[i];
      final sec = (c.secondaryLabel ?? '').trim();
      buf.write('${i + 1}. ${c.primaryLabel}');
      if (sec.isNotEmpty) buf.write(' — $sec');
      buf.write('\n');
    }
    buf.write('أي واحد تقصد؟');
    return buf.toString().trim();
  }
}
