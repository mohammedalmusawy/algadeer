import 'package:supabase_flutter/supabase_flutter.dart';

import '../doctors/doctor_availability_service.dart';
import '../doctors/doctor_gender.dart';
import '../models/doctor_item.dart';
import '../search/smart_search_models.dart';

enum MedicalNavigationAction {
  openDoctor,
  openLab,
  openPackage,
  openOffer,
  showSpecialtyHint,
  showAnalysisHint,
  urgentCare,
  blocked,
}

class MedicalNavigationDecision {
  const MedicalNavigationDecision({
    required this.action,
    required this.safeMessage,
    this.result,
    this.disclaimer,
  });

  final MedicalNavigationAction action;
  final String safeMessage;
  final SmartSearchResult? result;
  final String? disclaimer;
}

/// طبقة أمان وتوجيه — لا تشخيص ولا وصفات.
class MedicalNavigationService {
  static const defaultDisclaimer =
      'هذه المعلومات للتوجيه فقط وليست تشخيصًا طبيًا.';

  static final _blockedPatterns = RegExp(
    r'(شخّص|شخص|诊断|diagnos|وصفة|دواء|جرعة|علاج|أعراضي|symptom|cure|prescri)',
    caseSensitive: false,
  );

  /// علامات خطر تستدعي رعاية عاجلة — لا تشخيص ولا تحويل لبطاقة طبيب عادية.
  static final _redFlagPatterns = RegExp(
    r'(ألم\s*صدر|الم\s*صدر|chest\s*pain|نوبة\s*قلبية|سكتة|شلل\s*مفاجئ|صعوبة\s*تنفس\s*شديدة|ضيق\s*تنفس\s*شديد|نزيف\s*شديد|فقدان\s*وعي|اغماء|إغماء|تشنجات\s*مستمرة|انفجار|طلق\s*ناري|طعن|اختناق|emergency|urgent\s*care)',
    caseSensitive: false,
  );

  static const urgentCareMessage =
      'إذا كانت الأعراض شديدة أو مفاجئة، راجع أقرب مركز طوارئ أو اتصل بالطوارئ فوراً. '
      'لا أستطيع تشخيص الحالات الطارئة. هذه الرسالة للتوجيه الآمن فقط.';

  MedicalNavigationDecision decideForQuery(String query) {
    if (_redFlagPatterns.hasMatch(query)) {
      return const MedicalNavigationDecision(
        action: MedicalNavigationAction.urgentCare,
        safeMessage: urgentCareMessage,
        disclaimer: defaultDisclaimer,
      );
    }

    if (_blockedPatterns.hasMatch(query)) {
      return const MedicalNavigationDecision(
        action: MedicalNavigationAction.blocked,
        safeMessage: 'لا أستطيع تشخيص الحالات أو وصف العلاج. يمكنني مساعدتك في إيجاد طبيب أو مختبر مناسب.',
        disclaimer: defaultDisclaimer,
      );
    }

    return MedicalNavigationDecision(
      action: MedicalNavigationAction.showSpecialtyHint,
      safeMessage: 'ابحث عن طبيب أو اختصاص أو مختبر من القائمة.',
      disclaimer: defaultDisclaimer,
    );
  }

  MedicalNavigationDecision decideForResult(SmartSearchResult result) {
    switch (result.type) {
      case SmartSearchResultType.doctor:
        return MedicalNavigationDecision(
          action: MedicalNavigationAction.openDoctor,
          safeMessage: 'فتح ملف الطبيب ${result.title}',
          result: result,
          disclaimer: defaultDisclaimer,
        );
      case SmartSearchResultType.lab:
        return MedicalNavigationDecision(
          action: MedicalNavigationAction.openLab,
          safeMessage: 'فتح ملف المختبر ${result.title}',
          result: result,
          disclaimer: defaultDisclaimer,
        );
      case SmartSearchResultType.package:
        return MedicalNavigationDecision(
          action: MedicalNavigationAction.openPackage,
          safeMessage: 'عرض الباقة ${result.title}',
          result: result,
          disclaimer: defaultDisclaimer,
        );
      case SmartSearchResultType.offer:
        return MedicalNavigationDecision(
          action: MedicalNavigationAction.openOffer,
          safeMessage: 'فتح العرض ${result.title}',
          result: result,
          disclaimer: defaultDisclaimer,
        );
      case SmartSearchResultType.specialty:
        return MedicalNavigationDecision(
          action: MedicalNavigationAction.showSpecialtyHint,
          safeMessage: 'عرض أطباء اختصاص ${result.title}',
          result: result,
          disclaimer: defaultDisclaimer,
        );
      case SmartSearchResultType.analysis:
        return MedicalNavigationDecision(
          action: MedicalNavigationAction.showAnalysisHint,
          safeMessage:
              'التحليل ${result.title} — تظهر الباقات والمختبرات المرتبطة إن وُجدت',
          result: result,
          disclaimer: defaultDisclaimer,
        );
    }
  }

  /// تنسيق رد المساعد (نص أو AI) قبل عرضه/نطقه.
  String sanitizeAssistantReply(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return text;
    if (!_blockedPatterns.hasMatch(text)) {
      if (!text.contains('للتوجيه فقط')) {
        text = '$text\n\n$defaultDisclaimer';
      }
      return text;
    }
    return 'لا أستطيع تقديم تشخيص أو علاج. $defaultDisclaimer';
  }

  bool looksLikeMedicalDescription(String query) {
    final q = _normalize(query);
    final hasSymptoms = RegExp(
      r'(ألم|مغص|معدة|بطن|غثيان|قيء|إسهال|إمساك|حموضة|حرقان|حرقة|صداع|دوخة|تنميل|خدر|ضيق\s*نفس|سعال|حمّى|التهاب|طفل|أطفال|كسر|مفصل|جرح|خراج|كتلة|ورم|رقبة|ظهر|حلق|لوز|انف|أذن|اذن)',
      caseSensitive: false,
    ).hasMatch(q);

    final hasContextWords = RegExp(
      r'(عندي|لدي|عندي\s+|لدي\s+|أشعر|كنت\s+اعاني|اعاني)',
      caseSensitive: false,
    ).hasMatch(q);

    return hasSymptoms || hasContextWords;
  }

  List<MedicalNavigationSpecialtySuggestion> detectSpecialtiesFromDescription(
    String query,
  ) {
    final q = _normalize(query);

    int score(String keyword) => q.contains(keyword) ? 1 : 0;

    // خريطة بسيطة للكلمات الأكثر شيوعًا مقابل تخصصات النظام.
    final candidates = <MedicalNavigationSpecialtySuggestion>[];
    int addIfScore(String specialty, List<String> keywords, String reason) {
      var s = 0;
      for (final k in keywords) {
        s += score(k);
      }
      if (s > 0) {
        candidates.add(
          MedicalNavigationSpecialtySuggestion(
            specialty: specialty,
            reason: reason,
            score: s,
          ),
        );
      }
      return s;
    }

    addIfScore('باطنية', [
      'بطن',
      'معدة',
      'مغص',
      'غثيان',
      'قيء',
      'اسهال',
      'إسهال',
      'امساك',
      'إمساك',
      'حموضة',
      'حرقان',
      'حرقة',
    ], 'لأعراض الجهاز الهضمي');
    addIfScore('الجملة العصبية', [
      'صداع',
      'دوخة',
      'تنميل',
      'خدر',
      'رقبة',
      'ظهر',
      'ضعف',
      'تشوش',
    ], 'لأعراض عصبية مثل صداع/تنميل');
    addIfScore('أنف وأذن وحنجرة', [
      'حلق',
      'لوز',
      'انف',
      'أذن',
      'اذن',
      'التهاب',
    ], 'لأعراض الأنف/الأذن/الحلق');
    addIfScore('أطفال', [
      'طفل',
      'اطفال',
      'أطفال',
      'رضيع',
      'طفلة',
    ], 'لأعراض خاصة بالأطفال');
    addIfScore('جراحة عامة', [
      'جرح',
      'خراج',
      'كتلة',
      'ورم',
      'دمل',
      'خراج',
    ], 'للحالات التي قد تحتاج تدخل جراحي');
    addIfScore('كسور ومفاصل', [
      'كسر',
      'مفصل',
      'التواء',
      'سقطة',
      'ضربة',
    ], 'لمشاكل العظام والمفاصل');

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates;
  }

  Future<MedicalNavigationPlan> buildPlanForMedicalDescription(
    String query, {
    int limitPerSpecialty = 4,
    int maxDoctors = 10,
  }) async {
    final suggestions = detectSpecialtiesFromDescription(query);
    if (suggestions.isEmpty) {
      return MedicalNavigationPlan(specialties: const [], doctors: const []);
    }

    // fetch doctors real from Supabase
    final client = Supabase.instance.client;

    final doctorResults = <SmartSearchResult>[];
    for (final s in suggestions) {
      List<Map<String, dynamic>> rows = [];
      try {
        final data = await client
            .from('doctors')
            .select()
            .or('is_active.eq.true,is_active.is.null')
            .eq('specialty', s.specialty)
            .limit(limitPerSpecialty * 2);
        rows = (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {
        rows = [];
      }

      if (rows.isEmpty) {
        try {
          final data = await client
              .from('doctors')
              .select()
              .or('is_active.eq.true,is_active.is.null')
              .ilike('specialty', '%${s.specialty}%')
              .limit(limitPerSpecialty * 2);
          rows = (data as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } catch (_) {
          rows = [];
        }
      }

      final doctors = rows.map((r) => DoctorItem.fromMap(r)).toList();
      final ranked = doctors
        ..sort(
          (a, b) =>
              _doctorScore(
                b,
                s.specialty,
                suggestionIndex: suggestions.indexOf(s),
              ).compareTo(
                _doctorScore(
                  a,
                  s.specialty,
                  suggestionIndex: suggestions.indexOf(s),
                ),
              ),
        );

      for (final d in ranked.take(limitPerSpecialty)) {
        final leave = DoctorLeaveDisplay.fromDoctor(d);
        final suggestionBoost = 100 - suggestions.indexOf(s) * 5;
        doctorResults.add(
          SmartSearchResult(
            type: SmartSearchResultType.doctor,
            title: d.name,
            subtitle: d.specialty,
            doctorId: d.id,
            score: suggestionBoost.clamp(60, 100),
            imageUrl: d.imageUrl.isNotEmpty ? d.imageUrl : null,
            specialty: d.specialty,
            absenceBadge: leave.isOnLeave ? leave.badgeLabel : null,
            availabilityLabel: leave.isOnLeave
                ? leave.badgeLabel
                : (d.bookingStatus == 'available'
                      ? DoctorGender.availableShort(d.gender)
                      : null),
            bioSnippet: d.shortDescription.isNotEmpty
                ? d.shortDescription
                : (d.bio.isNotEmpty ? d.bio : null),
            isOnLeave: leave.isOnLeave,
          ),
        );
      }

      if (doctorResults.length >= maxDoctors) break;
    }

    return MedicalNavigationPlan(
      specialties: suggestions,
      doctors: doctorResults.take(maxDoctors).toList(),
    );
  }

  int _doctorScore(
    DoctorItem doctor,
    String specialty, {
    required int suggestionIndex,
  }) {
    final onLeave = DoctorLeaveDisplay.fromDoctor(doctor).isOnLeave;

    final status = doctor.bookingStatus.trim().toLowerCase();
    final hasAvailableStatus = _isDoctorEligibleNow(doctor);

    var score = 0;

    // الإجازة تُعطّل التصدر حتى لو كان doctor.available=true.
    if (onLeave) {
      score -= 200;
    } else {
      score += 200;
    }

    // ترتيب الاختصاص: الأفضل تظهر تخصصه أولاً.
    score += (60 - suggestionIndex * 10);

    // ranking حسب حالة الحجز.
    if (status == 'full') score += 80;
    if (status == 'available') score += 70;
    if (status == 'walk_in_only') score += 30;
    if (status == 'unavailable') score -= 80;

    // علامات إضافية (إدارية/نظام).
    if (doctor.ghadeerBadge) score += 15;
    score += (doctor.profileViews).clamp(0, 500) ~/ 20;

    // إذا لم يكن eligible حسب القواعد، نخفضه.
    if (!hasAvailableStatus) score -= 50;

    return score;
  }

  bool _isDoctorEligibleNow(DoctorItem doctor) {
    if (DoctorLeaveDisplay.fromDoctor(doctor).isOnLeave) return false;
    final status = doctor.bookingStatus.trim().toLowerCase();
    if (status == 'full') return true;
    if (status == 'walk_in_only' || status == 'unavailable') {
      return false;
    }
    return doctor.available;
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('\u0640', '') // tatweel
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ة', 'ه');
  }
}

class MedicalNavigationSpecialtySuggestion {
  const MedicalNavigationSpecialtySuggestion({
    required this.specialty,
    required this.reason,
    required this.score,
  });

  final String specialty;
  final String reason;
  final int score;
}

class MedicalNavigationPlan {
  const MedicalNavigationPlan({
    required this.specialties,
    required this.doctors,
  });

  final List<MedicalNavigationSpecialtySuggestion> specialties;
  final List<SmartSearchResult> doctors;
}
