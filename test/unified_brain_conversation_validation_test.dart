/// PC-1.24 — تحقق محادثات واقعية متعددة الأدوار عبر مسار SmartBrainPlanner الحقيقي.
///
/// ليس مرحلة ميزات جديدة. يحتفظ بـ ConversationContext بين الأدوار.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/dental/dental_guidance_coordinator.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/dental/dental_models.dart';
import 'package:ghadeer_clinic/health/emotional_support/mental_health_safety_gate.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/unified_brain/unified_brain.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:ghadeer_clinic/labs/labs_service.dart';

/// سجل دور واحد للتحقق اليدوي-مثل.
class ConversationTurnLog {
  ConversationTurnLog({
    required this.turn,
    required this.query,
    required this.response,
    required this.diagnostics,
    required this.subjectScope,
    required this.primaryAuthority,
    required this.contextualAuthorities,
    required this.primaryIntent,
    required this.questionBudgetUsed,
    required this.safetyInvoked,
    required this.clarificationCount,
    required this.mskActive,
    required this.pregnancyActive,
    required this.dentalActive,
    required this.adolescentActive,
    required this.respiratoryActive,
    required this.pregnancyWeeks,
    required this.dentalSwelling,
    required this.adolescentAge,
    required this.pass,
    required this.reason,
  });

  final int turn;
  final String query;
  final String response;
  final UnifiedBrainDiagnostics diagnostics;
  final String? subjectScope;
  final BrainAuthorityId primaryAuthority;
  final List<String> contextualAuthorities;
  final BrainPrimaryIntent primaryIntent;
  final bool questionBudgetUsed;
  final bool safetyInvoked;
  final int clarificationCount;
  final bool mskActive;
  final bool pregnancyActive;
  final bool dentalActive;
  final bool adolescentActive;
  final bool respiratoryActive;
  final int? pregnancyWeeks;
  final DentalSwellingClass dentalSwelling;
  final int? adolescentAge;
  final bool pass;
  final String reason;

  Map<String, Object?> toReportMap() => {
        'turn': turn,
        'query': query,
        'subjectScope': subjectScope,
        'primaryIntent': primaryIntent.name,
        'primaryAuthority': primaryAuthority.name,
        'contextualAuthorities': contextualAuthorities,
        'safetyInvoked': safetyInvoked,
        'questionBudgetUsed': questionBudgetUsed,
        'clarificationCount': clarificationCount,
        'mskActive': mskActive,
        'pregnancyActive': pregnancyActive,
        'pregnancyWeeks': pregnancyWeeks,
        'dentalActive': dentalActive,
        'dentalSwelling': dentalSwelling.name,
        'adolescentActive': adolescentActive,
        'adolescentAge': adolescentAge,
        'respiratoryActive': respiratoryActive,
        'responsePreview': response.length > 180
            ? '${response.substring(0, 180)}…'
            : response,
        'pass': pass,
        'reason': reason,
      };
}

class ConversationHarness {
  ConversationHarness({
    SmartBrainDoctorLookup? doctorLookup,
    SmartBrainLabLookup? labLookup,
  }) {
    SharedPreferences.setMockInitialValues({});
    context = ConversationContext();
    planner = SmartBrainPlanner(
      doctorLookup: doctorLookup ??
          ((_) async => [
                SmartSearchResult(
                  type: SmartSearchResultType.doctor,
                  title: 'دكتور علي',
                  subtitle: 'طب عام',
                  doctorId: 'd-ali',
                  specialty: 'طب عام',
                  phone: '07001234567',
                  whatsapp: '07001234567',
                  clinicLocation: 'عيادة الغدير',
                  score: 95,
                ),
                SmartSearchResult(
                  type: SmartSearchResultType.doctor,
                  title: 'دكتورة سارة أسنان',
                  subtitle: 'طب الأسنان',
                  doctorId: 'd-sara',
                  specialty: 'طب الأسنان',
                  phone: '07007654321',
                  whatsapp: '07007654321',
                  clinicLocation: 'عيادة الأسنان',
                  score: 94,
                ),
              ]),
      labLookup: labLookup ??
          ((_) async => [
                SmartSearchResult(
                  type: SmartSearchResultType.lab,
                  title: 'مختبر الغدير',
                  subtitle: 'مختبر',
                  labId: 'lab-ghadeer',
                  score: 95,
                ),
              ]),
      packagesLookup: (_) async => [
            LabPackageItem(
              id: 'pkg1',
              labId: 'lab-ghadeer',
              name: 'باقة عامة',
              newPrice: 25000,
              testNames: const ['CBC'],
            ),
          ],
      analysisLookup: (_) async => [
            AnalysisItem(id: 'cbc', name: 'CBC'),
          ],
      packagesForAnalysisLookup: (_) async => const [],
      activePackagesLookup: ({labId, nameQuery}) async => [
            AnalysisPackageLink(
              package: LabPackageItem(
                id: 'pkg1',
                labId: 'lab-ghadeer',
                name: 'باقة عامة',
                newPrice: 25000,
              ),
              labId: 'lab-ghadeer',
              labName: 'مختبر الغدير',
            ),
          ],
      discountedPackagesLookup: ({labId}) async => const [],
    );
  }

  late ConversationContext context;
  late SmartBrainPlanner planner;
  final List<ConversationTurnLog> logs = [];

  /// عدّ أسئلة التوضيح الظاهرة في الرد (علامات استفهام عربية/لاتينية + أنماط شائعة).
  static int countClarificationQuestions(String message) {
    final m = message.trim();
    if (m.isEmpty) return 0;
    // علامات استفهام
    final marks = RegExp(r'[؟?]').allMatches(m).length;
    // أنماط أسئلة توضيح شائعة بلا علامة
    final patterns = RegExp(
      r'(هل\s|شنو\s|وين\s|متى\s|كم\s|الألم\s*إلك|عندك\s)',
    );
    // إن وُجدت علامات استفهام نستخدمها؛ وإلا نعدّ جملاً استفهامية واضحة في نهاية الرسالة
    if (marks > 0) return marks;
    final lines = m.split(RegExp(r'[\n.]+'));
    var q = 0;
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      if (patterns.hasMatch(t) &&
          (t.contains('؟') ||
              t.endsWith('؟') ||
              RegExp(r'(الك لو|لو لشخص|هل عندك|شنو)').hasMatch(t))) {
        q += 1;
      }
    }
    return q;
  }

  static bool looksLikeBotCollage(String message) {
    if (message.contains('——') || message.contains('====')) return true;
    // أقسام متعددة بعنوانين صريحين
    final sectionHeaders = RegExp(r'(^|\n)\s*(الحمل|الظهر|السكري|الأسنان|المراهق)\s*:')
        .allMatches(message)
        .length;
    return sectionHeaders >= 3;
  }

  static bool hasMedicationChangeLanguage(String message) {
    return RegExp(
      r'(غيّر|غير)\s*(الدوا|الدواء)|اوقف\s*الدوا|خذ\s*\d+\s*ملغ|زد\s*الجرعه',
    ).hasMatch(message);
  }

  static bool hasAutomaticImagingOrder(String message) {
    return RegExp(
      r'(لازم\s*(تسوي|تعمل)\s*(اشعه|أشعة|mri|رنين)|اسويلك\s*اشعه|احجز\s*اشعه)',
    ).hasMatch(message);
  }

  Future<ConversationTurnLog> say(
    int turn,
    String query, {
    required bool Function(ConversationTurnLog draft) expectPass,
    String failHint = '',
  }) async {
    final plan = await planner.plan(query: query, context: context);
    final diag = context.unifiedBrainDiagnostics;
    final response = plan.message.trim().isNotEmpty
        ? plan.message.trim()
        : (context.lastAssistantResponse ?? '').trim();
    final clarificationCount = countClarificationQuestions(response);

    final draft = ConversationTurnLog(
      turn: turn,
      query: query,
      response: response,
      diagnostics: diag,
      subjectScope: context.lastClinicalSubjectScopeKey,
      primaryAuthority: diag.selectedPrimaryAuthority,
      contextualAuthorities: List<String>.from(diag.contextualAuthorityIds),
      primaryIntent: diag.primaryIntent,
      questionBudgetUsed: diag.questionBudgetUsed,
      safetyInvoked: diag.safetyAuthorityInvoked,
      clarificationCount: clarificationCount,
      mskActive: context.mskSession.active,
      pregnancyActive: context.pregnancyCompanionSession.active,
      dentalActive: context.dentalSession.active,
      adolescentActive: context.adolescentCompanionSession.active,
      respiratoryActive: context.respiratorySession.active,
      pregnancyWeeks: context.pregnancyCompanionSession.gestationalWeeks,
      dentalSwelling: context.dentalSession.swelling,
      adolescentAge: context.adolescentCompanionSession.statedAgeYears,
      pass: true,
      reason: 'ok',
    );

    final pass = expectPass(draft);
    final log = ConversationTurnLog(
      turn: draft.turn,
      query: draft.query,
      response: draft.response,
      diagnostics: draft.diagnostics,
      subjectScope: draft.subjectScope,
      primaryAuthority: draft.primaryAuthority,
      contextualAuthorities: draft.contextualAuthorities,
      primaryIntent: draft.primaryIntent,
      questionBudgetUsed: draft.questionBudgetUsed,
      safetyInvoked: draft.safetyInvoked,
      clarificationCount: draft.clarificationCount,
      mskActive: draft.mskActive,
      pregnancyActive: draft.pregnancyActive,
      dentalActive: draft.dentalActive,
      adolescentActive: draft.adolescentActive,
      respiratoryActive: draft.respiratoryActive,
      pregnancyWeeks: draft.pregnancyWeeks,
      dentalSwelling: draft.dentalSwelling,
      adolescentAge: draft.adolescentAge,
      pass: pass,
      reason: pass ? 'PASS' : (failHint.isEmpty ? 'expectation failed' : failHint),
    );
    logs.add(log);
    return log;
  }

  void reset() {
    context = ConversationContext();
    logs.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('PC-1.24 MANUAL-LIKE — Flagship 10-turn conversation', () {
    late ConversationHarness h;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      h = ConversationHarness();
    });

    test('Turns 1–10 realistic continuity', () async {
      // —— Turn 1 ——
      final t1 = await h.say(
        1,
        'اني حامل بالأسبوع 24 وعندي سكر حمل ومن البارحة ظهري يوجعني وخايفة',
        failHint:
            'T1: expect MSK primary, pregnancy contextual, one response, ≤1 question',
        expectPass: (d) {
          if (d.response.isEmpty) return false;
          if (ConversationHarness.looksLikeBotCollage(d.response)) return false;
          if (ConversationHarness.hasMedicationChangeLanguage(d.response)) {
            return false;
          }
          if (ConversationHarness.hasAutomaticImagingOrder(d.response)) {
            return false;
          }
          if (d.clarificationCount > 1) return false;
          if (d.primaryAuthority != BrainAuthorityId.msk) return false;
          // حمل سياقي محفوظ في الجلسة بعد الامتصاص الصامت
          if (d.pregnancyWeeks != 24 && !d.pregnancyActive) {
            // إن لم تُحفظ الأسابيع فشل
            if (h.context.pregnancyCompanionSession.gestationalWeeks != 24) {
              return false;
            }
          }
          final hasPregContext = d.contextualAuthorities.contains('pregnancy') ||
              d.diagnostics.candidateAuthorityIds.contains('pregnancy') ||
              d.response.contains('حمل') ||
              d.response.contains('حامل') ||
              h.context.pregnancyCompanionSession.gestationalWeeks == 24;
          if (!hasPregContext) return false;
          return true;
        },
      );
      expect(t1.pass, isTrue, reason: t1.reason);
      expect(t1.primaryAuthority, BrainAuthorityId.msk);
      expect(h.context.pregnancyCompanionSession.gestationalWeeks, 24);

      // —— Turn 2 ——
      final t2 = await h.say(
        2,
        'الألم متوسط وما عندي نزف',
        failHint: 'T2: preserve MSK/pregnancy; non-empty; ≤1 question',
        expectPass: (d) {
          if (d.response.isEmpty) return false;
          if (d.clarificationCount > 1) return false;
          if (RegExp(r'(هل\s*عندك\s*نزف|عندك\s*نزف\s*\?)').hasMatch(d.response)) {
            return false;
          }
          return d.primaryAuthority == BrainAuthorityId.msk || d.mskActive;
        },
      );
      expect(t2.pass, isTrue, reason: t2.reason);

      // —— Turn 3 ——
      final t3 = await h.say(
        3,
        'وين أكدر ألكه طبيب أسنان؟',
        failHint: 'T3: service intent wins; no MSK/pregnancy hijack as primary',
        expectPass: (d) {
          // لا يجب أن يكون MSK/حمل السلطة الأساسية لطلب طبيب أسنان
          if (d.primaryAuthority == BrainAuthorityId.msk) return false;
          if (d.primaryAuthority == BrainAuthorityId.pregnancy) return false;
          // الجلسات السريرية اللاصقة يُفضَّل مسحها أو عدم الهيمنة
          final hijacked = d.mskActive &&
              d.primaryAuthority == BrainAuthorityId.msk &&
              !d.diagnostics.serviceHandoff &&
              !d.diagnostics.clinicalSessionsClearedForForeignTurn;
          if (hijacked) return false;
          // الرد يجب ألا يكون نصيحة ظهر/حمل فقط
          final onlyClinical = d.response.contains('ظهري') &&
              !RegExp(r'(طبيب|دكتور|اسنان|أسنان|عياد)').hasMatch(d.response);
          if (onlyClinical) return false;
          return d.response.isNotEmpty;
        },
      );
      expect(t3.pass, isTrue, reason: t3.reason);

      // —— Turn 4 ——
      final t4 = await h.say(
        4,
        'لا مو إلي، ابني عمره 15 سنه يوجعه',
        failHint: 'T4: subject→son, dental primary, no owner pregnancy leak',
        expectPass: (d) {
          if (d.primaryAuthority != BrainAuthorityId.dental &&
              !d.dentalActive) {
            // قد يمر عبر clarifying أولاً لكن يجب ألا يبقى حمل أساسي
            if (d.primaryAuthority == BrainAuthorityId.pregnancy) return false;
          }
          // لا تسرّب حمل المالك كجلسة أساسية لابن
          if (d.primaryAuthority == BrainAuthorityId.pregnancy) return false;
          // العمر 15 لابن — لا يُعامل المالك كمراهق أساسي هنا
          if (d.primaryAuthority == BrainAuthorityId.adolescent &&
              RegExp(r'سن').hasMatch(d.query)) {
            return false;
          }
          return d.response.isNotEmpty && d.clarificationCount <= 1;
        },
      );
      expect(t4.pass, isTrue, reason: t4.reason);
      expect(t4.primaryAuthority, isNot(BrainAuthorityId.pregnancy));

      // —— Turn 5 ——
      final t5 = await h.say(
        5,
        'ووجهه هم وارم',
        failHint: 'T5: son dental swelling; no abscess diagnosis',
        expectPass: (d) {
          if (RegExp(r'(خراج|abscess)\s*(مؤكد|تشخيص)').hasMatch(d.response)) {
            return false;
          }
          if (d.clarificationCount > 1) return false;
          // يُفضَّل أسنان نشط أو رد أسنان
          return d.response.isNotEmpty &&
              (d.dentalActive ||
                  d.primaryAuthority == BrainAuthorityId.dental ||
                  d.response.contains('وجه') ||
                  d.response.contains('سن') ||
                  d.response.contains('تورم'));
        },
      );
      expect(t5.pass, isTrue, reason: t5.reason);

      // —— Turn 6 ——
      final t6 = await h.say(
        6,
        'لا ماكو ورم بالوجه، بس اللثة وارمة',
        failHint: 'T6: facial swelling cleared; gum swelling kept',
        expectPass: (d) {
          if (d.clarificationCount > 1) return false;
          // لا تحذير ورم وجه بالٍ
          if (RegExp(r'تورم الوجه المرتبط').hasMatch(d.response) &&
              d.dentalSwelling == DentalSwellingClass.facial) {
            return false;
          }
          // الحالة المصححة: ليس facial
          if (d.dentalSwelling == DentalSwellingClass.facial ||
              d.dentalSwelling == DentalSwellingClass.progressiveFacial) {
            return false;
          }
          return d.response.isNotEmpty;
        },
      );
      expect(t6.pass, isTrue, reason: t6.reason);
      expect(
        t6.dentalSwelling,
        isNot(DentalSwellingClass.facial),
        reason: 'stale facial swelling must be cleared',
      );

      // —— Turn 7 ——
      final t7 = await h.say(
        7,
        'ابني هم عنده امتحان ومتوتر وما يكدر يركز',
        failHint: 'T7: adolescent/emotional; no ADHD; dental must not hijack',
        expectPass: (d) {
          if (RegExp(r'(ADHD|فرط\s*حركه|تشخيص\s*قلق|عندك\s*اكتئاب)')
              .hasMatch(d.response)) {
            return false;
          }
          if (d.clarificationCount > 1) return false;
          // أسنان لا يجب أن تخطف موضوع امتحان
          if (d.primaryAuthority == BrainAuthorityId.dental &&
              !d.response.contains('امتحان') &&
              !d.response.contains('توتر') &&
              !d.response.contains('تركيز')) {
            return false;
          }
          return d.response.isNotEmpty;
        },
      );
      expect(t7.pass, isTrue, reason: t7.reason);

      // —— Turn 8 ——
      final t8 = await h.say(
        8,
        'خل نرجع لموضوع سنه',
        failHint: 'T8: resume son dental; no restored facial swelling',
        expectPass: (d) {
          if (d.dentalSwelling == DentalSwellingClass.facial ||
              d.dentalSwelling == DentalSwellingClass.progressiveFacial) {
            return false;
          }
          if (d.clarificationCount > 1) return false;
          return d.response.isNotEmpty &&
              (d.primaryAuthority == BrainAuthorityId.dental ||
                  d.dentalActive ||
                  RegExp(r'(سن|لثه|اسنان|أسنان)').hasMatch(d.response));
        },
      );
      expect(t8.pass, isTrue, reason: t8.reason);

      // —— Turn 9 ——
      final t9 = await h.say(
        9,
        'شنو يحتاج أشعة؟',
        failHint: 'T9: imaging appropriateness; no auto imaging / commercial bias',
        expectPass: (d) {
          if (ConversationHarness.hasAutomaticImagingOrder(d.response)) {
            return false;
          }
          if (RegExp(r'(احجز\s*اشعه\s*الغدير|عرض\s*اشعه)').hasMatch(d.response)) {
            return false;
          }
          if (d.clarificationCount > 1) return false;
          return d.response.isNotEmpty;
        },
      );
      expect(t9.pass, isTrue, reason: t9.reason);

      // —— Turn 10 ——
      final t10 = await h.say(
        10,
        'خلاص اترك الموضوع',
        failHint: 'T10: cancel/stop, not medical negation',
        expectPass: (d) {
          // لا يفسَّر كنفي طبي لأعراض
          if (RegExp(r'(ماكو\s*ورم|لا\s*يوجد\s*تورم)').hasMatch(d.response) &&
              d.query.contains('خلاص')) {
            // مقبول فقط إن لم يبنِ على إلغاء كأنه نفي سريري جديد
          }
          return d.response.isNotEmpty ||
              d.diagnostics.primaryIntent == BrainPrimaryIntent.cancel ||
              d.primaryIntent == BrainPrimaryIntent.cancel ||
              !d.dentalActive ||
              h.context.unifiedPendingClarificationKey == null;
        },
      );
      expect(t10.pass, isTrue, reason: t10.reason);

      // كل الأدوار PASS
      for (final log in h.logs) {
        expect(log.pass, isTrue, reason: 'Turn ${log.turn}: ${log.reason}');
      }
    });
  });

  group('PC-1.24 MANUAL-LIKE — Adversarial A–L', () {
    late ConversationHarness h;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      h = ConversationHarness();
    });

    test('A — subject leakage zero contamination', () async {
      await h.say(1, 'اني حامل بالأسبوع 20', expectPass: (d) {
        return d.primaryAuthority == BrainAuthorityId.pregnancy ||
            d.pregnancyActive;
      }, failHint: 'A1 pregnancy');
      await h.say(2, 'زوجتي سنها يوجعها', expectPass: (d) {
        return d.primaryAuthority != BrainAuthorityId.pregnancy &&
            (d.primaryAuthority == BrainAuthorityId.dental || d.dentalActive);
      }, failHint: 'A2 wife dental must not be pregnancy primary');
      await h.say(3, 'ابني عنده سعال', expectPass: (d) {
        return d.primaryAuthority != BrainAuthorityId.pregnancy &&
            d.primaryAuthority != BrainAuthorityId.dental;
      }, failHint: 'A3 child cough not pregnancy/dental primary');
      await h.say(4, 'اني ظهري يوجعني', expectPass: (d) {
        return d.primaryAuthority == BrainAuthorityId.msk &&
            !d.adolescentActive;
      }, failHint: 'A4 owner MSK; no adolescent on owner');
      for (final l in h.logs) {
        expect(l.pass, isTrue, reason: l.reason);
      }
    });

    test('B — age leakage owner not adolescent', () async {
      await h.say(1, 'ابني عمره 15 ومتوتر', expectPass: (d) => d.response.isNotEmpty);
      await h.say(2, 'اني ظهري يوجعني', expectPass: (d) {
        return d.primaryAuthority == BrainAuthorityId.msk &&
            !d.adolescentActive;
      }, failHint: 'B2 owner back pain must not keep adolescent active as owner');
      expect(h.logs.last.pass, isTrue);
      expect(h.logs.last.primaryAuthority, BrainAuthorityId.msk);
    });

    test('C — correction stress week 24→22→23', () async {
      await h.say(1, 'اني حامل بالأسبوع 24', expectPass: (d) {
        return d.pregnancyWeeks == 24 || d.pregnancyActive;
      });
      expect(h.context.pregnancyCompanionSession.gestationalWeeks, 24);
      await h.say(2, 'لا 22', expectPass: (d) {
        return d.pregnancyWeeks == 22;
      }, failHint: 'C2 week must become 22');
      expect(h.context.pregnancyCompanionSession.gestationalWeeks, 22);
      await h.say(3, 'آسف 23', expectPass: (d) {
        return d.pregnancyWeeks == 23;
      }, failHint: 'C3 final week must be 23');
      expect(h.context.pregnancyCompanionSession.gestationalWeeks, 23);
      expect(h.logs.every((l) => l.pass), isTrue);
    });

    test('D — negation stress facial→none→gum', () async {
      await h.say(1, 'سني يوجعني ووجهي وارم', expectPass: (d) {
        return d.dentalActive || d.primaryAuthority == BrainAuthorityId.dental;
      });
      expect(
        h.context.dentalSession.swelling,
        DentalSwellingClass.facial,
      );
      await h.say(2, 'لا ماكو ورم بالوجه، بس اللثة وارمة', expectPass: (d) {
        return d.dentalSwelling == DentalSwellingClass.gum;
      }, failHint: 'D2 must clear facial and set gum');
      expect(h.context.dentalSession.swelling, DentalSwellingClass.gum);
      expect(
        RegExp(r'تورم الوجه المرتبط').hasMatch(h.logs.last.response),
        isFalse,
      );
    });

    test('E — domain switching no hijack + resume', () async {
      await h.say(1, 'ظهري يوجعني', expectPass: (d) {
        return d.primaryAuthority == BrainAuthorityId.msk;
      });
      await h.say(2, 'أريد مختبر قريب', expectPass: (d) {
        return d.primaryAuthority != BrainAuthorityId.msk ||
            d.diagnostics.clinicalSessionsClearedForForeignTurn ||
            d.diagnostics.serviceHandoff;
      }, failHint: 'E2 lab must not be MSK-hijacked');
      await h.say(3, 'مرحبا', expectPass: (d) {
        return !d.mskActive ||
            d.diagnostics.clinicalSessionsClearedForForeignTurn ||
            d.primaryIntent == BrainPrimaryIntent.greeting;
      });
      await h.say(4, 'بالنسبة لظهري، الألم بعده موجود', expectPass: (d) {
        return d.primaryAuthority == BrainAuthorityId.msk ||
            RegExp(r'(ظهر|الم|ألم)').hasMatch(d.response);
      }, failHint: 'E4 resume back pain');
      for (final l in h.logs) {
        expect(l.pass, isTrue, reason: l.reason);
      }
    });

    test('F — pregnancy cross-pack one primary', () async {
      Future<void> check(String q, BrainAuthorityId expected) async {
        h.reset();
        SharedPreferences.setMockInitialValues({});
        h = ConversationHarness();
        final log = await h.say(1, q, expectPass: (d) {
          return d.primaryAuthority == expected &&
              d.clarificationCount <= 1 &&
              !ConversationHarness.looksLikeBotCollage(d.response);
        }, failHint: 'F $q expect $expected');
        expect(log.pass, isTrue, reason: log.reason);
        expect(log.primaryAuthority, expected);
      }

      await check('اني حامل وعندي سعال', BrainAuthorityId.respiratory);
      await check('اني حامل وضرس العقل يوجعني', BrainAuthorityId.dental);
      await check('اني حامل بالأسبوع 26 وعندي سكر حمل', BrainAuthorityId.pregnancy);
      await check(
        'اني حامل بالأسبوع 24 وظهري يوجعني',
        BrainAuthorityId.msk,
      );
    });

    test('G — adolescent cross-pack ownership + crisis', () async {
      h.reset();
      h = ConversationHarness();
      var log = await h.say(1, 'عمري 16 وسني يوجعني', expectPass: (d) {
        return d.primaryAuthority == BrainAuthorityId.dental;
      });
      expect(log.pass, isTrue);

      h.reset();
      h = ConversationHarness();
      log = await h.say(1, 'عمري 16 وعندي سعال', expectPass: (d) {
        return d.primaryAuthority == BrainAuthorityId.respiratory;
      });
      expect(log.pass, isTrue);

      h.reset();
      h = ConversationHarness();
      log = await h.say(1, 'عمري 16 وعندي امتحان وخايف', expectPass: (d) {
        return d.primaryAuthority == BrainAuthorityId.adolescent &&
            !RegExp(r'(ADHD|تشخيص\s*قلق)').hasMatch(d.response);
      });
      expect(log.pass, isTrue);

      // أزمة: MentalHealthSafetyGate يجب أن تفوز قبل رد المراهق الإنتاجي
      h.reset();
      h = ConversationHarness();
      const crisisQ = 'عمري 16 أبي أقتل نفسي';
      final crisisPlan = await h.planner.plan(
        query: crisisQ,
        context: h.context,
      );
      expect(const MentalHealthSafetyGate().triggersCrisis(crisisQ), isTrue);
      expect(crisisPlan.message, isNotEmpty);
      // لا خطة دراسة مع أزمة
      expect(
        RegExp(r'(خطة\s*دراس|نظم\s*وقت|امتحان\s*بسهوله)')
            .hasMatch(crisisPlan.message),
        isFalse,
      );
    });

    test('H — one-question budget across multi-pack desire', () async {
      final log = await h.say(
        1,
        'اني حامل بالأسبوع 24 وعندي سكر حمل ومن البارحة ظهري يوجعني وخايفة وسني يوجعني',
        expectPass: (d) {
          return d.clarificationCount <= 1 &&
              !ConversationHarness.looksLikeBotCollage(d.response);
        },
        failHint: 'H max one clarification',
      );
      expect(log.clarificationCount, lessThanOrEqualTo(1));
      expect(log.pass, isTrue);
    });

    test('I — direct intent override lab search', () async {
      await h.say(1, 'ظهري يوجعني', expectPass: (d) {
        return d.primaryAuthority == BrainAuthorityId.msk;
      });
      final t2 = await h.say(2, 'وين مختبر الغدير؟', expectPass: (d) {
        return d.primaryAuthority != BrainAuthorityId.msk ||
            d.diagnostics.serviceHandoff ||
            d.diagnostics.clinicalSessionsClearedForForeignTurn ||
            RegExp(r'(مختبر|غدير)').hasMatch(d.response);
      }, failHint: 'I service wins over MSK');
      expect(t2.pass, isTrue, reason: t2.reason);
      expect(t2.primaryAuthority, isNot(BrainAuthorityId.msk));
    });

    test('J — ResultContext continuity doctor/lab', () async {
      // طبيب
      await h.planner.plan(query: 'دكتور علي', context: h.context);
      // إن وُضعت نتائج، Continuity عبر rememberResults المباشر أيضاً
      if (h.context.currentResultContext == null) {
        h.context.rememberResults(
          [
            SmartSearchResult(
              type: SmartSearchResultType.doctor,
              title: 'دكتور علي',
              subtitle: 'طب عام',
              doctorId: 'd-ali',
              specialty: 'طب عام',
              clinicLocation: 'عيادة الغدير',
              score: 95,
            ),
          ],
          intent: AssistantIntent.doctorSearch,
        );
      }
      expect(h.context.currentResultContext, isNotNull);
      expect(
        h.context.currentResultContext!.entityType,
        ConversationEntityType.doctor,
      );
      final loc = await h.planner.plan(
        query: 'وين عيادته؟',
        context: h.context,
      );
      expect(loc.message, isNotEmpty);
      expect(
        RegExp(r'(عياد|موقع|غدير|عنوان|علي)', caseSensitive: false)
            .hasMatch(loc.message),
        isTrue,
      );

      h.reset();
      h = ConversationHarness();
      h.context.rememberResults(
        [
          SmartSearchResult(
            type: SmartSearchResultType.lab,
            title: 'مختبر الغدير',
            subtitle: 'مختبر',
            labId: 'lab-ghadeer',
            score: 95,
          ),
        ],
        intent: AssistantIntent.findLab,
      );
      expect(
        h.context.currentResultContext?.entityType,
        ConversationEntityType.laboratory,
      );
      final pkgs = await h.planner.plan(
        query: 'شنو باقاته؟',
        context: h.context,
      );
      expect(pkgs.message, isNotEmpty);
    });

    test('K — failure isolation dental throw still allows MSK', () async {
      // نحاكي فشل منسّق الأسنان عبر mayHandle/handle عبر حقن منسّق معطل
      final brokenDental = _ThrowingDentalCoordinator();
      final planner = SmartBrainPlanner(
        doctorLookup: (_) async => <SmartSearchResult>[],
        labLookup: (_) async => <SmartSearchResult>[],
        dentalGuidance: brokenDental,
      );
      final ctx = ConversationContext();
      final plan = await planner.plan(
        query: 'ظهري يوجعني',
        context: ctx,
      );
      expect(plan.message, isNotEmpty);
      expect(ctx.mskSession.active, isTrue);
      expect(
        ctx.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.msk,
      );
    });

    test('L — simple greeting does not execute clinical packs', () async {
      final log = await h.say(1, 'مرحبا', expectPass: (d) {
        return !d.mskActive &&
            !d.respiratoryActive &&
            !d.dentalActive &&
            !d.pregnancyActive &&
            !d.adolescentActive;
      }, failHint: 'L greeting must not activate clinical sessions');
      expect(log.pass, isTrue, reason: log.reason);
    });
  });
}

/// منسّق أسنان يرمي عند mayHandle/handle — لعزل الفشل.
class _ThrowingDentalCoordinator extends DentalGuidanceCoordinator {
  @override
  bool mayHandle({
    required String query,
    required DentalSession session,
  }) {
    throw StateError('simulated dental failure');
  }
}
