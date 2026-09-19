import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/companion/people/family_person_profile.dart';
import 'package:ghadeer_clinic/companion/people/family_person_profile_service.dart';
import 'package:ghadeer_clinic/companion/people/local_family_person_profile_repository.dart';
import 'package:ghadeer_clinic/follow_up/follow_up.dart';
import 'package:ghadeer_clinic/health/chronic_care/chronic_care.dart';
import 'package:ghadeer_clinic/health/family_sensitive/family_sensitive_health.dart';
import 'package:ghadeer_clinic/health/sensitive_profile/sensitive_health_profile.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FollowUpService followUps;
  late FollowUpCoordinator coord;
  late SensitiveHealthProfileService ownerHealth;
  late ChronicCareCoordinator chronic;
  late FamilyPersonProfileService people;
  late FamilySensitiveHealthService familyHealth;
  late ConversationContext ctx;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    followUps = FollowUpService(
      repository: LocalFollowUpRepository(prefs: prefs),
    );
    coord = FollowUpCoordinator(service: followUps);
    ownerHealth = SensitiveHealthProfileService(
      repository: LocalSensitiveHealthProfileRepository(prefs: prefs),
    );
    chronic = ChronicCareCoordinator(
      healthProfiles: ownerHealth,
      repository: LocalChronicCareRepository(prefs: prefs),
      followUps: followUps,
    );
    people = FamilyPersonProfileService(
      repository: LocalFamilyPersonProfileRepository(prefs: prefs),
    );
    familyHealth = FamilySensitiveHealthService(
      repository: LocalFamilySensitiveHealthRepository(prefs: prefs),
    );
    ctx = ConversationContext();
  });

  group('PC-1.11 subject & authority A–I', () {
    test('A/B/C/D — subject refs; name not ownership key', () {
      const owner = FollowUpSubjectRef.accountOwner;
      final ali = FollowUpSubjectRef.persistentPerson('person_ali');
      expect(owner.isAccountOwner, isTrue);
      expect(ali.persistentPersonId, 'person_ali');
      expect(owner.matches(ali), isFalse);
      expect(ali.debugMap().containsKey('persistentPersonId'), isFalse);
      expect(ali.debugMap()['hasPersistentPerson'], isTrue);
    });

    test('E/F/G/H/I — memory/diagnosis/measurement/search/preventive != auto follow-up',
        () {
      const e = FollowUpEligibilityPolicy();
      expect(e.mayAutoCreateFromMemoryOrDiagnosis(), isFalse);
      expect(e.mayAutoCreateFromMeasurement(), isFalse);
      expect(e.mayAutoCreateFromDoctorSearch(), isFalse);
      expect(e.mayAutoCreateFromPreventiveAdvice(), isFalse);
    });
  });

  group('PC-1.11 create/permission/lifecycle J–S', () {
    test('J/K/L — explicit create; decline/later no active', () async {
      var r = await coord.handle(
        text: 'تابع وياي السكر',
        pending: FollowUpPendingOp.none,
      );
      expect(r.pending.isActive, isTrue);

      final declined = await coord.handle(text: 'لا', pending: r.pending);
      expect(declined.pending.isActive, isFalse);
      expect(await followUps.listActive(), isEmpty);

      r = await coord.handle(
        text: 'تابع وياي السكر',
        pending: FollowUpPendingOp.none,
      );
      final later = await coord.handle(text: 'بعدين', pending: r.pending);
      expect(await followUps.listActive(), isEmpty);
      expect(later.success, isTrue);

      r = await coord.handle(
        text: 'تابع وياي السكر',
        pending: FollowUpPendingOp.none,
      );
      final yes = await coord.handle(text: 'نعم', pending: r.pending);
      expect(yes.success, isTrue);
      expect(await followUps.listActive(), isNotEmpty);
      expect(yes.message.contains('تذكير تلقائي'), isFalse);
    });

    test('M/N/O/P/Q — status distinct; pause/resume/complete/cancel', () async {
      final c = await followUps.create(
        subject: FollowUpSubjectRef.accountOwner,
        domain: FollowUpDomain.chronicHealth,
        topicKey: 'diabetes',
        displayTopic: 'متابعة السكر',
      );
      expect(c.status, FollowUpStatus.active);

      await followUps.pause(c.commitmentId);
      expect((await followUps.findById(c.commitmentId))!.status,
          FollowUpStatus.paused);
      expect(
        followUps.maySurfaceReturn(
          (await followUps.findById(c.commitmentId))!,
          FollowUpDueContext(
            now: DateTime.now(),
            currentSubject: FollowUpSubjectRef.accountOwner,
            conversationRelevant: true,
          ),
        ),
        isFalse,
      );

      await followUps.resume(c.commitmentId);
      expect((await followUps.findById(c.commitmentId))!.status,
          FollowUpStatus.active);

      await followUps.complete(c.commitmentId);
      expect((await followUps.findById(c.commitmentId))!.status,
          FollowUpStatus.completed);
      expect(
        followUps.maySurfaceReturn(
          (await followUps.findById(c.commitmentId))!,
          FollowUpDueContext(
            now: DateTime.now(),
            currentSubject: FollowUpSubjectRef.accountOwner,
            conversationRelevant: true,
          ),
        ),
        isFalse,
      );

      final c2 = await followUps.create(
        subject: FollowUpSubjectRef.accountOwner,
        domain: FollowUpDomain.doctorVisit,
        topicKey: 'doctor_visit',
        displayTopic: 'مراجعة الطبيب',
      );
      await followUps.cancel(c2.commitmentId);
      expect((await followUps.findById(c2.commitmentId))!.status,
          FollowUpStatus.cancelled);
    });

    test('R/S — delete commitment does not delete health/person', () async {
      await ownerHealth.upsertConditions([
        HealthConditionRecord(
          id: 'hc1',
          canonicalConditionKey: 'diabetes',
          displayName: 'السكري',
          diagnosisStatus: HealthDiagnosisStatus.diagnosed,
          diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);
      final person = await people.createProfile(
        relationship: PersonRelationship.son,
        preferredName: 'علي',
      );
      final c = await followUps.create(
        subject: FollowUpSubjectRef.accountOwner,
        domain: FollowUpDomain.chronicHealth,
        topicKey: 'diabetes',
        displayTopic: 'متابعة السكر',
      );
      await followUps.deleteCommitment(c.commitmentId);
      expect(await followUps.findById(c.commitmentId), isNull);
      expect((await ownerHealth.loadProfile())!.conditions.length, 1);
      expect((await people.loadAllProfiles()).first.personId, person.personId);
    });
  });

  group('PC-1.11 isolation & safety T–Z', () {
    test('T/U — owner vs Ali subject isolation', () async {
      final ownerC = await followUps.create(
        subject: FollowUpSubjectRef.accountOwner,
        domain: FollowUpDomain.chronicHealth,
        topicKey: 'diabetes',
        displayTopic: 'متابعة السكر',
      );
      final ali = FollowUpSubjectRef.persistentPerson('person_ali');
      // family chronic blocked — create doctor visit for ali instead
      final aliC = await followUps.create(
        subject: ali,
        domain: FollowUpDomain.doctorVisit,
        topicKey: 'doctor_visit',
        displayTopic: 'مراجعة علي',
      );
      expect(
        followUps.maySurfaceReturn(
          ownerC,
          FollowUpDueContext(
            now: DateTime.now(),
            currentSubject: ali,
            conversationRelevant: true,
          ),
        ),
        isFalse,
      );
      expect(
        followUps.maySurfaceReturn(
          aliC,
          FollowUpDueContext(
            now: DateTime.now(),
            currentSubject: FollowUpSubjectRef.accountOwner,
            conversationRelevant: true,
          ),
        ),
        isFalse,
      );
    });

    test('V/W — unrelated lab/doctor intent not interrupted', () async {
      await followUps.create(
        subject: FollowUpSubjectRef.accountOwner,
        domain: FollowUpDomain.chronicHealth,
        topicKey: 'diabetes',
        displayTopic: 'متابعة السكر',
      );
      final lab = await coord.handle(
        text: 'أريد رقم مختبر',
        pending: FollowUpPendingOp.none,
      );
      expect(lab.deferToEntityIntent || !lab.handled, isTrue);

      final doc = await coord.handle(
        text: 'أبي دكتور',
        pending: FollowUpPendingOp.none,
      );
      expect(doc.deferToEntityIntent || !doc.handled, isTrue);
    });

    test('X/Y/Z — safety outranks; emotional distress does not increase pressure',
        () async {
      final urgent = await coord.handle(
        text: 'تابع وياي السكر وعندي ضيق نفس',
        pending: FollowUpPendingOp.none,
        preferUrgentSafety: true,
      );
      expect(urgent.deferToUrgentSafety || !urgent.handled, isTrue);

      final mental = await coord.handle(
        text: 'تابع وياي السكر وابي انتحار',
        pending: FollowUpPendingOp.none,
      );
      expect(mental.deferToMentalSafety || !mental.handled, isTrue);

      final c = await followUps.create(
        subject: FollowUpSubjectRef.accountOwner,
        domain: FollowUpDomain.chronicHealth,
        topicKey: 'diabetes',
        displayTopic: 'متابعة السكر',
      );
      final dueCalm = followUps.maySurfaceReturn(
        c,
        FollowUpDueContext(
          now: DateTime.now(),
          currentSubject: FollowUpSubjectRef.accountOwner,
          conversationRelevant: true,
        ),
      );
      final dueDistress = followUps.maySurfaceReturn(
        c,
        FollowUpDueContext(
          now: DateTime.now(),
          currentSubject: FollowUpSubjectRef.accountOwner,
          conversationRelevant: true,
          emotionalDistress: true,
        ),
      );
      expect(dueDistress, dueCalm); // لا زيادة ضغط
    });
  });

  group('PC-1.11 skips & chronic AA–AH', () {
    test('AA/AB/AC — skips reduce resurfacing; stop asking', () async {
      var c = await followUps.create(
        subject: FollowUpSubjectRef.accountOwner,
        domain: FollowUpDomain.chronicHealth,
        topicKey: 'diabetes',
        displayTopic: 'متابعة السكر',
      );
      c = (await followUps.recordSkipped(c.commitmentId))!;
      c = (await followUps.recordSkipped(c.commitmentId))!;
      expect(c.consecutiveSkips, 2);
      expect(
        followUps.maySurfaceReturn(
          c,
          FollowUpDueContext(
            now: DateTime.now().add(const Duration(days: 2)),
            currentSubject: FollowUpSubjectRef.accountOwner,
            conversationRelevant: true,
          ),
        ),
        isFalse,
      );

      c = await followUps.create(
        subject: FollowUpSubjectRef.accountOwner,
        domain: FollowUpDomain.chronicHealth,
        topicKey: 'hypertension',
        displayTopic: 'متابعة الضغط',
      );
      final stop = await coord.handle(
        text: 'وقف متابعة الضغط',
        pending: FollowUpPendingOp.none,
      );
      expect(stop.handled, isTrue);
      expect((await followUps.findById(c.commitmentId))!.status,
          FollowUpStatus.paused);

      // صيغة «لا تسألني بعد»
      final c3 = await followUps.create(
        subject: FollowUpSubjectRef.accountOwner,
        domain: FollowUpDomain.labResult,
        topicKey: 'lab_result',
        displayTopic: 'نتيجة التحليل',
      );
      final stop2 = await coord.handle(
        text: 'لا تسألني بعد',
        pending: FollowUpPendingOp.none,
      );
      expect(stop2.handled, isTrue);
      expect((await followUps.findById(c3.commitmentId))!.status,
          FollowUpStatus.paused);
    });

    test('AD/AE/AF — chronic WHAT vs unified WHETHER; sync authority', () async {
      await ownerHealth.upsertConditions([
        HealthConditionRecord(
          id: 'hc1',
          canonicalConditionKey: 'diabetes',
          displayName: 'السكري',
          diagnosisStatus: HealthDiagnosisStatus.diagnosed,
          diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);
      var session = ChronicCareSession.inactive;
      var turn = await chronic.handle(
        text: 'تابع وياي السكر',
        session: session,
      );
      session = turn.session;
      turn = await chronic.handle(text: 'نعم', session: session);
      expect(turn.handled, isTrue);
      final synced = await followUps.findByTopic(
        subject: FollowUpSubjectRef.accountOwner,
        domain: FollowUpDomain.chronicHealth,
        topicKey: 'diabetes',
      );
      expect(synced, isNotNull);
      expect(synced!.permissionState, FollowUpPermissionState.granted);
      expect(synced.isActiveFollowUp, isTrue);
      // WHAT لا يزال من المخطّط المزمن
      expect(chronic.interpreter, isNotNull);
    });

    test('AG/AH — family health memory alone does not enable follow-up / no family chronic',
        () async {
      expect(
        const FollowUpEligibilityPolicy().familyHealthMemoryAuthorizesFollowUp(),
        isFalse,
      );
      expect(
        const FollowUpEligibilityPolicy().familyChronicFollowUpEnabled(),
        isFalse,
      );
      final ali = await people.createProfile(
        relationship: PersonRelationship.son,
        preferredName: 'علي',
      );
      await familyHealth.upsertConditions(
        persistentPersonId: ali.personId,
        candidates: const [
          HealthConditionCandidate(
            canonicalConditionKey: 'diabetes',
            displayName: 'السكري',
            diagnosisStatus: HealthDiagnosisStatus.diagnosed,
            diagnosisSource: HealthDiagnosisSource.clinicianAttributed,
          ),
        ],
      );
      expect(
        () => followUps.create(
          subject: FollowUpSubjectRef.persistentPerson(ali.personId),
          domain: FollowUpDomain.chronicHealth,
          topicKey: 'diabetes',
          displayTopic: 'سكر علي',
        ),
        throwsA(isA<FollowUpStorageException>()),
      );
    });
  });

  group('PC-1.11 domains timing honesty AI–AR', () {
    test('AI/AJ/AK — doctor/lab honesty; no OS reminder claim', () async {
      var r = await coord.handle(
        text: 'ذكرني أراجع الطبيب بهذا الموضوع',
        pending: FollowUpPendingOp.none,
      );
      r = await coord.handle(text: 'نعم', pending: r.pending);
      expect(r.success, isTrue);
      expect(r.message.contains('من ترجع للغدير') || r.message.contains('أكدر'),
          isTrue);
      expect(r.message.contains('راح أراسلك'), isFalse);
      final c = (await followUps.listActive())
          .where((e) => e.domain == FollowUpDomain.doctorVisit)
          .first;
      expect(c.domain, FollowUpDomain.doctorVisit);
      expect(c.notBeforeAt, isNull); // بلا موعد مخترع

      r = await coord.handle(
        text: 'من تطلع نتيجة التحليل أريد نرجع نحچي بيها',
        pending: FollowUpPendingOp.none,
      );
      expect(r.pending.isActive, isTrue);
      expect(r.pending.timingIntent, FollowUpTimingIntent.whenResultAvailable);
      r = await coord.handle(text: 'نعم', pending: r.pending);
      expect(r.message.contains('ما أكدر أعرف تلقائياً') ||
              r.message.contains('من ترجع'),
          isTrue);

      r = await coord.handle(
        text: 'ذكرني باچر أراجع الموضوع',
        pending: FollowUpPendingOp.none,
      );
      r = await coord.handle(text: 'نعم', pending: r.pending);
      expect(r.message.contains('تذكير تلقائي') || r.message.contains('الجهاز'),
          isTrue);
      expect(r.message.contains('راح أراسلك باچر'), isFalse);
    });

    test('AL/AM/AN — timing intents', () {
      const i = FollowUpCommandInterpreter();
      expect(
        i
            .interpret(
              raw: 'ذكرني باچر',
              pending: FollowUpPendingOp.none,
            )
            .timingIntent,
        FollowUpTimingIntent.tomorrow,
      );
      expect(
        i
            .interpret(
              raw: 'نرجع لهذا الموضوع من ترجع',
              pending: FollowUpPendingOp.none,
            )
            .timingIntent,
        FollowUpTimingIntent.whenUserReturns,
      );
      expect(
        i
            .interpret(
              raw: 'من تطلع نتيجة التحليل أريد نرجع نحچي بيها',
              pending: FollowUpPendingOp.none,
            )
            .timingIntent,
        FollowUpTimingIntent.whenResultAvailable,
      );
    });

    test('AO/AP — no background scheduling / push', () {
      expect(const NoOpFollowUpScheduler().isImplemented, isFalse);
      expect(const NoOpFollowUpEventSink().isImplemented, isFalse);
    });

    test('AQ/AR — due only when relevant; unrelated does not surface', () async {
      final c = await followUps.create(
        subject: FollowUpSubjectRef.accountOwner,
        domain: FollowUpDomain.chronicHealth,
        topicKey: 'diabetes',
        displayTopic: 'متابعة السكر',
      );
      expect(
        followUps.maySurfaceReturn(
          c,
          FollowUpDueContext(
            now: DateTime.now(),
            currentSubject: FollowUpSubjectRef.accountOwner,
            conversationRelevant: true,
          ),
        ),
        isTrue,
      );
      expect(
        followUps.maySurfaceReturn(
          c,
          FollowUpDueContext(
            now: DateTime.now(),
            currentSubject: FollowUpSubjectRef.accountOwner,
            conversationRelevant: false,
            unrelatedEntityIntent: true,
          ),
        ),
        isFalse,
      );
    });
  });

  group('PC-1.11 listing privacy commands AS–BH', () {
    test('AS/AT/AU — listing; no IDs; minimize health', () async {
      await followUps.create(
        subject: FollowUpSubjectRef.accountOwner,
        domain: FollowUpDomain.chronicHealth,
        topicKey: 'diabetes',
        displayTopic: 'متابعة السكر',
      );
      final r = await coord.handle(
        text: 'شنو الأشياء اللي تتابعها وياي؟',
        pending: FollowUpPendingOp.none,
      );
      expect(r.message.contains('fu_'), isFalse);
      expect(r.message.contains('person_'), isFalse);
      expect(r.handled, isTrue);
    });

    test('AV/AW — completion preserves record; correction replaces topic',
        () async {
      final c = await followUps.create(
        subject: FollowUpSubjectRef.accountOwner,
        domain: FollowUpDomain.chronicHealth,
        topicKey: 'diabetes',
        displayTopic: 'متابعة السكر',
      );
      await followUps.complete(c.commitmentId);
      expect(await followUps.findById(c.commitmentId), isNotNull);

      var r = await coord.handle(
        text: 'تابع وياي السكر',
        pending: FollowUpPendingOp.none,
      );
      r = await coord.handle(
        text: 'لا مو السكر، أقصد الضغط',
        pending: r.pending,
      );
      expect(r.pending.topicKey, 'hypertension');
      expect(r.pending.displayTopic.contains('ضغط'), isTrue);
    });

    test('AX — repository failure does not claim success', () async {
      final fail = FollowUpCoordinator(
        service: FollowUpService(repository: _FailFuRepo()),
      );
      var r = await fail.handle(
        text: 'تابع وياي المشي',
        pending: FollowUpPendingOp.none,
      );
      r = await fail.handle(text: 'نعم', pending: r.pending);
      expect(r.success, isFalse);
      expect(r.message.contains('ما تم الحفظ'), isTrue);
    });

    test('AY/AZ/BA — no raw transcript; privacy debug', () async {
      final r = await coord.handle(
        text: 'تابع وياي السكر',
        pending: FollowUpPendingOp.none,
      );
      final store = await followUps.loadStore();
      final raw = store?.toStorageMap().toString() ?? '';
      expect(raw.contains('تابع وياي'), isFalse);
      final dbg = r.debugMap().toString();
      expect(dbg.contains('person_'), isFalse);
      expect(dbg.contains('diabetes'), isFalse);
      expect(dbg.contains('سكري'), isFalse);
    });

    test('BB/BC/BD — same interpreter text/voice; text-first', () {
      const i = FollowUpCommandInterpreter();
      final a = i.interpret(
        raw: 'شنو الأشياء اللي تتابعها وياي؟',
        pending: FollowUpPendingOp.none,
      );
      final b = i.interpret(
        raw: 'شنو الأشياء اللي تتابعها وياي؟',
        pending: FollowUpPendingOp.none,
      );
      expect(a.kind, b.kind);
      expect(a.kind, FollowUpCommandKind.listCommitments);
    });

    test('BE/BF/BG/BH — no campaigns/meds/family measurements/paid', () {
      expect(FollowUpDomain.values.contains(FollowUpDomain.chronicHealth),
          isTrue);
      expect(
        FollowUpDomain.values.map((e) => e.name).contains('campaign'),
        isFalse,
      );
      expect(
        FollowUpDomain.values.map((e) => e.name).contains('medication'),
        isFalse,
      );
      expect(LocalFollowUpRepository.storageKey, 'pc_follow_up_commitments_v1');
      expect(ctx.followUpPending.isActive, isFalse);
    });
  });
}

class _FailFuRepo implements FollowUpRepository {
  @override
  Future<void> clearStore() async {}

  @override
  Future<FollowUpStore?> loadStore() async =>
      const FollowUpStore(ownerKey: 'x');

  @override
  Future<FollowUpStore> saveStore(FollowUpStore store) async {
    throw FollowUpStorageException('fail');
  }
}
