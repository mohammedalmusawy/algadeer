/// Phase 2A — دورة حياة ConversationContext فقط.
///
/// بلا استخراج عمر، بلا Phase 2B، بلا طبقة سياق ثانية.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/musculoskeletal/msk_models.dart';
import 'package:ghadeer_clinic/clinical_knowledge/packs/respiratory/respiratory_models.dart';
import 'package:ghadeer_clinic/health/subject/health_subject_models.dart';
import 'package:ghadeer_clinic/memory/memory_session_policy.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/unified_brain/unified_brain_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';

void main() {
  late ConversationContext ctx;

  SmartSearchResult doc(String id, String title) => SmartSearchResult(
        type: SmartSearchResultType.doctor,
        title: title,
        subtitle: 'طب الأطفال',
        doctorId: id,
        specialty: 'طب الأطفال',
        phone: '0700$id',
        whatsapp: '0700$id',
        clinicLocation: 'الكرادة',
        score: 90,
      );

  RespiratorySession activeCough() => const RespiratorySession(
        active: true,
        topic: RespiratoryTopic.acuteCough,
        durationBucket: RespiratoryDurationBucket.days,
        fever: RespiratoryTriState.unknown,
        breathlessness: RespiratoryTriState.unknown,
        population: RespiratoryPopulation.child,
        lastQuestionKey: 'childAssociated',
        symptomKeys: ['cough'],
      );

  setUp(() {
    ctx = ConversationContext();
  });

  group('A — الجيل الابتدائي', () {
    test('ConversationContext جديد يبدأ بالجيل الابتدائي', () {
      expect(ctx.conversationGeneration, kInitialConversationGeneration);
      expect(ctx.lastResetReason, ConversationResetReason.none);
      expect(ctx.healthSubject, HealthSubjectContext.unknown);
      expect(ctx.turnId, 0);
    });
  });

  group('B — الدور العادي لا يحرّك الجيل', () {
    test('rememberQuery وadvanceTurn وجلسة تنفسية لا تزيد الجيل', () {
      ctx.rememberQuery('ابني عنده سعال من يومين');
      ctx.advanceTurn();
      ctx.setRespiratorySession(activeCough());
      ctx.setHealthSubject(
        const HealthSubjectContext(
          sessionKey: 'subj_child_session',
          type: HealthSubjectType.child,
          evidence: HealthSubjectEvidence.explicitRelationship,
        ),
      );

      expect(ctx.conversationGeneration, kInitialConversationGeneration);
      expect(ctx.lastResetReason, ConversationResetReason.none);
      expect(ctx.respiratorySession.active, isTrue);
      expect(ctx.healthSubject.type, HealthSubjectType.child);
    });
  });

  group('C — reset الكامل', () {
    test('reset يزيد الجيل ويمسح الحالة بما فيها healthSubject', () {
      ctx.setRespiratorySession(activeCough());
      ctx.setHealthSubject(
        const HealthSubjectContext(
          sessionKey: 'subj_child_session',
          type: HealthSubjectType.child,
          evidence: HealthSubjectEvidence.explicitRelationship,
        ),
      );
      ctx.rememberQuery('سعال', intent: AssistantIntent.generalSearch);
      ctx.advanceTurn();

      ctx.reset();

      expect(ctx.conversationGeneration, kInitialConversationGeneration + 1);
      expect(ctx.lastResetReason, ConversationResetReason.explicitUserReset);
      expect(ctx.respiratorySession.active, isFalse);
      expect(ctx.healthSubject, HealthSubjectContext.unknown);
      expect(ctx.lastQuery, isNull);
      expect(ctx.turnId, 0);
    });

    test('reset(pageDisposed) يزيد الجيل بنفس أثر الجلسة الكاملة', () {
      ctx.reset(reason: ConversationResetReason.pageDisposed);
      expect(ctx.conversationGeneration, kInitialConversationGeneration + 1);
      expect(ctx.lastResetReason, ConversationResetReason.pageDisposed);
    });
  });

  group('D — مسح نتائج البحث لا يدمّر الجلسة السريرية', () {
    test('beginNewDoctorSearch يبقي السعال النشط والجيل', () {
      ctx.setRespiratorySession(activeCough());
      ctx.rememberResults(
        [doc('d1', 'علي ناصر'), doc('d2', 'سارة')],
        query: 'أريد طبيب أطفال',
        intent: AssistantIntent.doctorSearch,
      );
      final generation = ctx.conversationGeneration;
      final fever = ctx.respiratorySession.fever;
      final lastQ = ctx.respiratorySession.lastQuestionKey;

      ctx.beginNewDoctorSearch(query: 'طبيب جلدية');

      expect(ctx.conversationGeneration, generation);
      expect(ctx.lastResetReason, ConversationResetReason.none);
      expect(ctx.respiratorySession.active, isTrue);
      expect(ctx.respiratorySession.fever, fever);
      expect(ctx.respiratorySession.lastQuestionKey, lastQ);
      expect(ctx.currentResultContext, isNull);
      expect(ctx.selectedDoctor, isNull);
    });

    test('invalidateAuthoritativeResultContext لا يمسح الحزمة التنفسية', () {
      ctx.setRespiratorySession(activeCough());
      ctx.rememberResults([doc('d1', 'علي ناصر')]);
      ctx.invalidateAuthoritativeResultContext(reason: 'test');

      expect(ctx.conversationGeneration, kInitialConversationGeneration);
      expect(ctx.respiratorySession.active, isTrue);
      expect(ctx.currentResultContext, isNull);
    });
  });

  group('E — تبديل الموضوع السريري', () {
    test('noteClinicalSubjectScope عند التبديل يمسح الحزم الشقيقة ويزيد الجيل', () {
      ctx.setRespiratorySession(activeCough());
      ctx.setMskSession(const MskSession(active: true));
      ctx.setHealthSubject(
        const HealthSubjectContext(
          sessionKey: 'subj_child_session',
          type: HealthSubjectType.child,
          evidence: HealthSubjectEvidence.explicitRelationship,
        ),
      );

      expect(ctx.noteClinicalSubjectScope('owner'), isFalse);
      expect(ctx.conversationGeneration, kInitialConversationGeneration);
      expect(ctx.respiratorySession.active, isTrue);

      expect(ctx.noteClinicalSubjectScope('other'), isTrue);
      expect(ctx.conversationGeneration, kInitialConversationGeneration + 1);
      expect(ctx.lastResetReason, ConversationResetReason.subjectChanged);
      expect(ctx.respiratorySession.active, isFalse);
      expect(ctx.mskSession.active, isFalse);
      expect(ctx.healthSubject, HealthSubjectContext.unknown);
    });

    test('دورة أجنبية تمسح الحزم وتزيد الجيل دون بحث جديد', () {
      ctx.setRespiratorySession(activeCough());
      ctx.clearClinicalPackSessionsForForeignTurn();

      expect(ctx.conversationGeneration, kInitialConversationGeneration + 1);
      expect(ctx.lastResetReason, ConversationResetReason.foreignTurn);
      expect(ctx.respiratorySession.active, isFalse);
    });

    test('invalidateSiblingClinicalSessions لا يحرّك الجيل', () {
      ctx.setRespiratorySession(activeCough());
      ctx.setMskSession(const MskSession(active: true));
      ctx.invalidateSiblingClinicalSessions(primary: BrainAuthorityId.respiratory);

      expect(ctx.conversationGeneration, kInitialConversationGeneration);
      expect(ctx.respiratorySession.active, isTrue);
      expect(ctx.mskSession.active, isFalse);
    });
  });

  group('F — ممنوع التسلسل الدائم', () {
    test('ConversationContext يبقى جلسة فقط', () {
      expect(ctx.allowsPersistentMemorySerialization, isFalse);
      expect(
        const MemorySessionOnlyPolicy().maySerializeConversationContextAsMemory(),
        isFalse,
      );
      expect(
        const MemorySessionOnlyPolicy().mayAutoPersistSymptomConversation(),
        isFalse,
      );
    });
  });

  group('G — ResultContext يبقى المصدر السلطوي', () {
    test('lastResults المعروضة لا تُستخدم للترتيب بعد rememberResults', () {
      final d1 = doc('d1', 'علي');
      final d2 = doc('d2', 'سارة');
      final d3 = doc('d3', 'زيد');
      ctx.rememberResults([d1, d2], intent: AssistantIntent.doctorSearch);
      ctx.lastResults = [d1, d2, d3];

      expect(ctx.currentResultContext, isNotNull);
      expect(ctx.currentResultContext!.entityType, ConversationEntityType.doctor);
      expect(ctx.authoritativeItemsFor(ConversationEntityType.doctor), [d1, d2]);
      expect(ctx.lastResults.length, 3);
    });
  });

  group('H — السلوك التنفسي القائم لا يتغيّر بهذا التأسيس', () {
    test('تعيين الجلسة التنفسية يبقى كما هو عبر الأدوار العادية', () {
      final session = activeCough();
      ctx.setRespiratorySession(session);
      ctx.rememberQuery('8 سنوات');
      ctx.advanceTurn();

      expect(ctx.respiratorySession.active, isTrue);
      expect(ctx.respiratorySession.population, RespiratoryPopulation.child);
      expect(ctx.respiratorySession.durationBucket, RespiratoryDurationBucket.days);
      expect(ctx.respiratorySession.lastQuestionKey, 'childAssociated');
      expect(ctx.respiratorySession.symptomKeys, contains('cough'));
      expect(ctx.respiratorySession.fever, RespiratoryTriState.unknown);
      expect(ctx.conversationGeneration, kInitialConversationGeneration);
    });
  });
}
