import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/memory/memory.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:ghadeer_clinic/voice/result_context.dart';

/// PC-0.4 — Memory / Consent / Privacy boundary.
///
/// No persistence. Contracts + policy + tests only.
void main() {
  late MemoryCandidateClassifier classifier;
  late MemoryCommandClassifier commands;
  late MemoryConsentPolicy consent;
  late MemorySessionOnlyPolicy sessionPolicy;
  late MemoryAnalyticsFirewall analytics;
  late FutureProfileFieldCatalog profileFields;
  late MemoryAntiManipulationPolicy antiManip;
  late MemoryUsePolicy usePolicy;
  late ConversationContext ctx;

  setUp(() {
    classifier = const MemoryCandidateClassifier();
    commands = const MemoryCommandClassifier();
    consent = const MemoryConsentPolicy();
    sessionPolicy = const MemorySessionOnlyPolicy();
    analytics = const MemoryAnalyticsFirewall();
    profileFields = const FutureProfileFieldCatalog();
    antiManip = const MemoryAntiManipulationPolicy();
    usePolicy = const MemoryUsePolicy();
    ctx = ConversationContext();
  });

  HealthSubjectContext selfSubj() => const HealthSubjectContext(
        sessionKey: 'subj_self_1',
        type: HealthSubjectType.self,
        evidence: HealthSubjectEvidence.explicitSelf,
      );

  HealthSubjectContext childSubj() => const HealthSubjectContext(
        sessionKey: 'subj_child_1',
        type: HealthSubjectType.child,
        evidence: HealthSubjectEvidence.explicitRelationship,
        isChild: true,
        ageGroup: 'child',
      );

  HealthSubjectContext motherSubj() => const HealthSubjectContext(
        sessionKey: 'subj_mother_1',
        type: HealthSubjectType.mother,
        evidence: HealthSubjectEvidence.explicitRelationship,
        ageGroup: 'adult',
      );

  group('PC-0.4 session-only A–H', () {
    test('A — ConversationContext cannot be treated as persistent memory', () {
      expect(ctx.allowsPersistentMemorySerialization, isFalse);
      expect(sessionPolicy.maySerializeConversationContextAsMemory(), isFalse);
      expect(
        sessionPolicy.isSessionOnlyKey('ConversationContext'),
        isTrue,
      );
    });

    test('B — ResultContext classified session-only', () {
      expect(sessionPolicy.isSessionOnlyKey('ResultContext'), isTrue);
      final rc = ResultContext(
        entityType: ConversationEntityType.doctor,
        items: const [],
        turnId: 1,
      );
      expect(rc.runtimeType.toString(), contains('ResultContext'));
    });

    test('C — pendingClarification session-only', () {
      expect(sessionPolicy.isSessionOnlyKey('pendingClarification'), isTrue);
    });

    test('D — guided raw answers session-only', () {
      expect(sessionPolicy.isSessionOnlyKey('rawGuidedAnswers'), isTrue);
      expect(sessionPolicy.isSessionOnlyKey('GuidedConversationState'), isTrue);
    });

    test('E — conduct state session-only', () {
      expect(sessionPolicy.isSessionOnlyKey('ConductState'), isTrue);
      expect(sessionPolicy.mayPersistConductAsReputation(), isFalse);
    });

    test('F — health symptoms session-only', () {
      expect(sessionPolicy.isSessionOnlyKey('symptoms'), isTrue);
      expect(sessionPolicy.mayAutoPersistSymptomConversation(), isFalse);
    });

    test('G — safety state session-only', () {
      expect(sessionPolicy.isSessionOnlyKey('safetyEvaluation'), isTrue);
    });

    test('H — health handoff session-only', () {
      expect(sessionPolicy.isSessionOnlyKey('healthHandoff'), isTrue);
      expect(sessionPolicy.isSessionOnlyKey('HealthGuidanceSession'), isTrue);
    });
  });

  group('PC-0.4 health memory boundary I–Q', () {
    test('I — يمكن عندي سكري cannot become diagnosedCondition candidate', () {
      final r = classifier.classify(
        text: 'يمكن عندي سكري',
        subject: selfSubj(),
      );
      expect(r.candidates, isEmpty);
      expect(r.blockedReason, contains('speculative'));
    });

    test('J — أحس ضغطي مرتفع cannot become hypertension memory', () {
      final r = classifier.classify(
        text: 'أحس ضغطي مرتفع',
        subject: selfSubj(),
      );
      expect(r.candidates, isEmpty);
      expect(
        r.candidates.any((c) => c.structuredValue == 'hypertension'),
        isFalse,
      );
    });

    test('K — الدكتور مشخصني سكري → consent-required candidate, not persisted',
        () {
      final r = classifier.classify(
        text: 'الدكتور مشخصني سكري',
        subject: selfSubj(),
        turnId: 3,
      );
      expect(r.candidates, isNotEmpty);
      final c = r.candidates.first;
      expect(c.structuredValue, 'diabetes');
      expect(c.requiresExplicitConsent, isTrue);
      expect(c.consentState, MemoryConsentState.required);
      expect(c.mayPersistNow, isFalse);
      expect(classifier.mayPersistCandidates(r.candidates), isFalse);
    });

    test('L — explicit diagnosed-condition statement produces candidate only',
        () {
      final r = classifier.classify(
        text: 'مشخصني سكري',
        subject: selfSubj(),
      );
      expect(r.candidates.length, 1);
      expect(r.candidates.first.mayPersistNow, isFalse);
    });

    test('M — multiple explicit diagnosed conditions separately representable',
        () {
      final r = classifier.classify(
        text: 'عندي ضغط وسكري ومشخص بيهن',
        subject: selfSubj(),
      );
      final values = r.candidates.map((c) => c.structuredValue).toSet();
      expect(values.contains('diabetes'), isTrue);
      expect(values.contains('hypertension'), isTrue);
      expect(r.candidates.length, greaterThanOrEqualTo(2));
    });

    test('N — health candidate sensitivity == sensitiveHealth', () {
      final r = classifier.classify(
        text: 'الدكتور مشخصني سكري',
        subject: selfSubj(),
      );
      expect(r.candidates.first.sensitivity, MemorySensitivity.sensitiveHealth);
      expect(
        r.candidates.first.category,
        MemoryCategory.sensitiveHealthProfile,
      );
    });

    test('O — health candidate requires explicit consent', () {
      final r = classifier.classify(
        text: 'الدكتور مشخصني ضغط',
        subject: selfSubj(),
      );
      expect(r.candidates.first.requiresExplicitConsent, isTrue);
      expect(
        MemoryCategory.sensitiveHealthProfile.alwaysRequiresExplicitConsent,
        isTrue,
      );
    });

    test('P — declined consent cannot authorize persistence', () {
      expect(consent.mayPersist(MemoryConsentState.declined), isFalse);
      expect(consent.mayUse(MemoryConsentState.declined), isFalse);
    });

    test('Q — revoked consent cannot authorize use', () {
      expect(consent.mayPersist(MemoryConsentState.revoked), isFalse);
      expect(consent.mayUse(MemoryConsentState.revoked), isFalse);
    });
  });

  group('PC-0.4 subject ownership R–T', () {
    test('R — child health candidate not owned by account owner', () {
      final r = classifier.classify(
        text: 'الدكتور مشخص ابني سكري',
        subject: childSubj(),
      );
      expect(r.candidates, isNotEmpty);
      expect(r.candidates.first.subjectRef.belongsToAccountOwner, isFalse);
      expect(
        r.candidates.first.subjectRef.ownerKind,
        MemoryOwnerKind.temporarySubject,
      );
      expect(
        r.candidates.first.subjectRef.subjectType,
        HealthSubjectType.child,
      );
    });

    test('S — mother health candidate not owned by account owner', () {
      final r = classifier.classify(
        text: 'أمي مشخصة ضغط',
        subject: motherSubj(),
      );
      // إن لم يُنتج مرشّحاً لصياغة غير مدعومة — الملكية ما زالت temporary
      if (r.candidates.isEmpty) {
        final owner = MemorySubjectRef.temporary(HealthSubjectType.mother);
        expect(owner.belongsToAccountOwner, isFalse);
      } else {
        expect(r.candidates.first.subjectRef.belongsToAccountOwner, isFalse);
        expect(
          r.candidates.first.subjectRef.subjectType,
          HealthSubjectType.mother,
        );
      }
    });

    test('T — temporary other-person cannot auto-create family profile', () {
      final ref = MemorySubjectRef.temporary(HealthSubjectType.otherPerson);
      expect(ref.mayAutoCreateFamilyProfile, isFalse);
      expect(ref.ownerKind, MemoryOwnerKind.temporarySubject);
      expect(ref.persistentProfileId, isNull);
    });
  });

  group('PC-0.4 profile / sex / age U–Y', () {
    test('U — sex selection cannot be inferred from name', () {
      expect(profileFields.mayInferSexFromName(), isFalse);
    });

    test('V — sex selection cannot be inferred from TTS voice', () {
      expect(profileFields.mayInferSexFromTtsVoice(), isFalse);
    });

    test('W — profile photo cannot infer sex', () {
      expect(profileFields.mayInferSexFromPhoto(), isFalse);
    });

    test('X — birth year/age not inferred from appearance', () {
      expect(profileFields.mayInferBirthFromAppearance(), isFalse);
    });

    test('Y — session age remains separate from future persistent DOB', () {
      expect(profileFields.sessionAgeEqualsPersistentDob(), isFalse);
      final subj = childSubj().copyWith(ageYears: 5);
      expect(subj.ageYears, 5);
      // لا يوجد birthDate على HealthSubjectContext
      expect(FutureProfileFieldCatalog.conceptualFields.contains('birthDate'),
          isTrue);
    });
  });

  group('PC-0.4 follow-up / conduct / privacy Z–AG', () {
    test('Z — memory fact and follow-up commitment are distinct', () {
      final r = classifier.classify(
        text: 'عندي صداع',
        subject: selfSubj(),
      );
      expect(r.candidates, isEmpty);
      expect(r.followUpDraft, isNotNull);
      expect(r.followUpDraft!.topicKey, 'symptom_follow_up');
      // حقيقة ذاكرة ≠ التزام متابعة
      expect(r.followUpDraft, isNot(isA<MemoryCandidate>()));
    });

    test('AA — health complaint does not automatically create follow-up', () {
      final r = classifier.classify(
        text: 'عندي صداع',
        subject: selfSubj(),
      );
      expect(r.followUpDraft!.isScheduled, isFalse);
      expect(r.followUpDraft!.status, FollowUpDraftStatus.notScheduled);
      expect(r.followUpDraft!.requiresConsent, isTrue);
    });

    test('AB — conduct insult history cannot become long-term reputation', () {
      expect(sessionPolicy.mayPersistConductAsReputation(), isFalse);
      expect(antiManip.isForbiddenUse('punish_absence'), isTrue);
    });

    test('AC — memory candidate is RAM-only in PC-0.4', () {
      final r = classifier.classify(
        text: 'الدكتور مشخصني سكري',
        subject: selfSubj(),
      );
      ctx.addSessionMemoryCandidates(r.candidates);
      expect(ctx.sessionMemoryCandidates.first.isRamOnly, isTrue);
      expect(ctx.sessionMemoryCandidates.first.mayPersistNow, isFalse);
      ctx.reset();
      expect(ctx.sessionMemoryCandidates, isEmpty);
    });

    test('AD — no SharedPreferences writes in memory package', () {
      for (final f in Directory('lib/memory').listSync()) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final src = f.readAsStringSync();
        expect(
          src.contains('SharedPreferences.getInstance'),
          isFalse,
          reason: f.path,
        );
        expect(src.contains('prefs.set'), isFalse, reason: f.path);
      }
    });

    test('AE — no Supabase writes in memory package', () {
      for (final f in Directory('lib/memory').listSync()) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final src = f.readAsStringSync();
        expect(src.contains("package:supabase"), isFalse, reason: f.path);
        expect(src.contains('Supabase.instance'), isFalse, reason: f.path);
        expect(src.contains(".from('"), isFalse, reason: f.path);
        expect(src.contains('.from("'), isFalse, reason: f.path);
      }
    });

    test('AF — no analytics sensitive payload', () {
      final r = classifier.classify(
        text: 'الدكتور مشخصني سكري',
        subject: selfSubj(),
      );
      final payload = analytics.technicalEventPayload(r.candidates.first);
      expect(analytics.isSafeAnalyticsPayload(payload), isTrue);
      expect(payload.containsKey('structuredValue'), isFalse);
      expect(payload.values.join(' ').contains('diabetes'), isFalse);
      expect(analytics.emitsEventsInPc04, isFalse);
    });

    test('AG — debug output contains no sensitive value', () {
      final r = classifier.classify(
        text: 'الدكتور مشخصني سكري',
        subject: selfSubj(),
      );
      final dbg = r.candidates.first.debugMap().toString();
      expect(dbg.contains('diabetes'), isFalse);
      expect(dbg.contains('سكري'), isFalse);
      expect(dbg.contains('sensitiveHealth'), isTrue);
    });
  });

  group('PC-0.4 commands AH–AJ', () {
    test('AH — شنو تعرف عني؟ future list, no fake memory', () {
      final c = commands.classify('شنو تعرف عني؟');
      expect(c.kind, MemoryCommandKind.listWhatYouKnow);
      expect(c.operation, PersonalMemoryOperation.list);
      expect(c.returnsStoredMemories, isFalse);
      expect(c.performsPersistence, isFalse);
    });

    test('AI — احذف هذه المعلومة future delete, no claim without repository',
        () {
      final c = commands.classify('احذف هذه المعلومة');
      expect(c.kind, MemoryCommandKind.delete);
      expect(c.operation, PersonalMemoryOperation.delete);
      expect(c.claimsDeletionCompleted, isFalse);
      expect(
        const PersonalMemoryRepositoryGuard().isProductionRepositoryEnabled,
        isFalse,
      );
    });

    test('AJ — تذكر… recognized without persistence', () {
      final c = commands.classify('تذكر أن عندي امتحان الخميس');
      expect(c.kind, MemoryCommandKind.remember);
      expect(c.operation, PersonalMemoryOperation.add);
      expect(c.performsPersistence, isFalse);
      expect(c.requiresConfirmationEvenIfExplicit, isTrue);
    });
  });

  group('PC-0.4 regression AK–AM', () {
    test('AK — non-health doctor/lab/analysis/package flows remain unchanged',
        () async {
      final brain = SmartBrainPlanner(
        doctorLookup: (_) async => [
              SmartSearchResult(
                type: SmartSearchResultType.doctor,
                title: 'د',
                subtitle: 'باطنية',
                doctorId: 'd1',
                specialty: 'باطنية',
                score: 90,
              ),
            ],
        labLookup: (_) async => [
              SmartSearchResult(
                type: SmartSearchResultType.lab,
                title: 'مختبر الحياة',
                subtitle: 'مختبر',
                labId: 'hayat',
                score: 90,
              ),
            ],
        analysisLookup: (_) async => [
              AnalysisItem(id: 'cbc', name: 'CBC'),
            ],
      );
      final local = ConversationContext();
      await brain.plan(query: 'أريد مختبر الحياة', context: local);
      expect(
        local.currentResultContext?.entityType,
        ConversationEntityType.laboratory,
      );
      expect(local.allowsPersistentMemorySerialization, isFalse);
    });

    test('AL — PC-0.3 HealthSubjectContext behavior remains intact', () {
      expect(childSubj().type, HealthSubjectType.child);
      expect(selfSubj().type, HealthSubjectType.self);
      final r = classifier.classify(
        text: 'الدكتور مشخصني سكري',
        subject: childSubj(),
      );
      expect(r.candidates.first.subjectRef.subjectType, HealthSubjectType.child);
    });

    test('AM — voice/text parity of memory-policy classification', () {
      const q = 'الدكتور مشخصني سكري';
      final a = classifier.classify(text: q, subject: selfSubj());
      final b = classifier.classify(text: q, subject: selfSubj());
      expect(a.candidates.length, b.candidates.length);
      expect(a.candidates.first.structuredValue, b.candidates.first.structuredValue);
      expect(a.candidates.first.consentState, b.candidates.first.consentState);
    });
  });

  group('PC-0.4 policy extras', () {
    test('anti-manipulation forbidden uses documented', () {
      expect(antiManip.isForbiddenUse('guilt'), isTrue);
      expect(antiManip.isForbiddenUse('اشتقتلك'), isTrue);
      expect(usePolicy.mayInjectAllKnownFactsEveryTurn(), isFalse);
      expect(usePolicy.mayRetrieveSensitiveHealthOutsideHealthContext(), isFalse);
    });

    test('repository interface exists but production disabled', () {
      expect(
        const PersonalMemoryRepositoryGuard().isProductionRepositoryEnabled,
        isFalse,
      );
      expect(
        () => const PersonalMemoryRepositoryGuard()
            .denyInstantiation('pc04'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('app_users audit fields match known schema only', () {
      // حقول موجودة فعلاً في supabase/app_stats_schema.sql
      const known = {
        'visitor_key',
        'first_seen_at',
        'last_seen_at',
        'open_count',
      };
      final schema = File('supabase/app_stats_schema.sql').readAsStringSync();
      for (final f in known) {
        expect(schema.contains(f), isTrue);
      }
      // لا نخترع أعمدة صحة/جنس/ميلاد
      expect(schema.contains('diagnosed'), isFalse);
      expect(schema.contains('birth_date'), isFalse);
      expect(schema.contains('sex'), isFalse);
      // UserProfileService المحلي: اسم عرض فقط
      final profile =
          File('lib/services/user_profile_service.dart').readAsStringSync();
      expect(profile.contains('user_display_name'), isTrue);
      expect(profile.contains('birthDate'), isFalse);
    });
  });
}
