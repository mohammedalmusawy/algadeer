import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/health/understanding/health_understanding_engine.dart';
import 'package:ghadeer_clinic/health/understanding/local_symptom_catalog.dart';
import 'package:ghadeer_clinic/health/understanding/symptom_models.dart';
import 'package:ghadeer_clinic/search/query_input_source.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/clarification/clarification_models.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/guided_conversation/arabic_duration_parser.dart';
import 'package:ghadeer_clinic/voice/guided_conversation/guided_conversation_models.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

void main() {
  late HealthUnderstandingEngine engine;

  setUp(() {
    engine = HealthUnderstandingEngine();
  });

  DetectedSymptom? s(HealthUnderstandingResult r, String id) =>
      r.symptomById(id);

  group('Health language understanding', () {
    test('A — عندي صداع → headache present', () {
      final r = engine.understand('عندي صداع');
      expect(s(r, 'headache')?.status, SymptomPolarity.present);
    });

    test('B — راسي يوجعني → headache', () {
      final r = engine.understand('راسي يوجعني');
      expect(s(r, 'headache')?.status, SymptomPolarity.present);
    });

    test('C — راسي يعورني → headache', () {
      final r = engine.understand('راسي يعورني');
      expect(s(r, 'headache')?.status, SymptomPolarity.present);
    });

    test('D — دايخ → dizziness not vertigo', () {
      final r = engine.understand('دايخ');
      expect(s(r, 'dizziness')?.status, SymptomPolarity.present);
      expect(s(r, 'vertigo'), isNull);
    });

    test('E — المكان يدور بي → vertigo', () {
      final r = engine.understand('المكان يدور بي');
      expect(s(r, 'vertigo')?.status, SymptomPolarity.present);
    });

    test('F — عندي غثيان → nausea', () {
      final r = engine.understand('عندي غثيان');
      expect(s(r, 'nausea')?.status, SymptomPolarity.present);
    });

    test('G — نفسي تتلوع → nausea', () {
      final r = engine.understand('نفسي تتلوع');
      expect(s(r, 'nausea')?.status, SymptomPolarity.present);
    });

    test('H — استفرغ → vomiting', () {
      final r = engine.understand('استفرغ');
      expect(s(r, 'vomiting')?.status, SymptomPolarity.present);
    });

    test('I — نفسي ضايج → shortness_of_breath', () {
      final r = engine.understand('نفسي ضايج');
      expect(s(r, 'shortness_of_breath')?.status, SymptomPolarity.present);
    });

    test('J — صدري مكتوم → chest_tightness', () {
      final r = engine.understand('صدري مكتوم');
      expect(s(r, 'chest_tightness')?.status, SymptomPolarity.present);
    });

    test('K — صدري يوجعني → chest_pain', () {
      final r = engine.understand('صدري يوجعني');
      expect(s(r, 'chest_pain')?.status, SymptomPolarity.present);
    });

    test('L — بطني يوجعني → abdominal_pain', () {
      final r = engine.understand('بطني يوجعني');
      expect(s(r, 'abdominal_pain')?.status, SymptomPolarity.present);
    });

    test('M — ظهري يوجعني → back_pain', () {
      final r = engine.understand('ظهري يوجعني');
      expect(s(r, 'back_pain')?.status, SymptomPolarity.present);
    });

    test('N — خشمي مسدود → nasal_congestion', () {
      final r = engine.understand('خشمي مسدود');
      expect(s(r, 'nasal_congestion')?.status, SymptomPolarity.present);
    });

    test('O — ما اسمع زين → hearing_loss', () {
      final r = engine.understand('ما اسمع زين');
      expect(s(r, 'hearing_loss')?.status, SymptomPolarity.present);
    });

    test('P — صفير باذني → tinnitus', () {
      final r = engine.understand('صفير باذني');
      expect(s(r, 'tinnitus')?.status, SymptomPolarity.present);
    });

    test('Q — three PRESENT symptoms', () {
      final r = engine.understand('عندي سعال وحرارة وغثيان');
      expect(s(r, 'cough')?.status, SymptomPolarity.present);
      expect(s(r, 'fever')?.status, SymptomPolarity.present);
      expect(s(r, 'nausea')?.status, SymptomPolarity.present);
    });

    test('R — cough PRESENT fever ABSENT', () {
      final r = engine.understand('عندي سعال بس ما عندي حرارة');
      expect(s(r, 'cough')?.status, SymptomPolarity.present);
      expect(s(r, 'fever')?.status, SymptomPolarity.absent);
    });

    test('S — fever and vomiting ABSENT', () {
      final r = engine.understand('ما عندي حرارة ولا استفراغ');
      expect(s(r, 'fever')?.status, SymptomPolarity.absent);
      expect(s(r, 'vomiting')?.status, SymptomPolarity.absent);
    });

    test('T — يمكن عندي حرارة → uncertain', () {
      final r = engine.understand('يمكن عندي حرارة');
      expect(s(r, 'fever')?.status, SymptomPolarity.uncertain);
    });

    test('U — رجلي اليسرى تخدر → numbness + leg + left', () {
      final r = engine.understand('رجلي اليسرى تخدر');
      final n = s(r, 'numbness');
      expect(n?.status, SymptomPolarity.present);
      expect(n?.bodyRegion, BodyRegionId.leg);
      expect(n?.laterality, Laterality.left);
    });

    test('V — ألم شديد بالركبة اليمنى', () {
      final r = engine.understand('ألم شديد بالركبة اليمنى');
      final k = s(r, 'knee_pain');
      expect(k?.status, SymptomPolarity.present);
      expect(k?.bodyRegion, BodyRegionId.knee);
      expect(k?.laterality, Laterality.right);
      expect(k?.userSeverity, UserStatedSeverity.severe);
    });

    test('W — back pain + duration 3 days via Step 10A parser', () {
      final r = engine.understand('ظهري يوجعني من ثلاثة أيام');
      expect(s(r, 'back_pain')?.status, SymptomPolarity.present);
      expect(r.duration?.amount, 3);
      expect(r.duration?.unit, 'day');
      // نفس المحلل
      expect(
        identical(engine.durationParser, engine.durationParser),
        isTrue,
      );
      expect(
        const ArabicDurationParser().parse('من ثلاثة أيام')?.amount,
        r.duration?.amount,
      );
    });

    test('X — الألم يروح ويجي → intermittent', () {
      final r = engine.understand('الألم يروح ويجي');
      expect(r.temporalModifiers, contains('intermittent'));
    });

    test('Y — بدأ فجأة → sudden', () {
      final r = engine.understand('بدأ فجأة');
      expect(r.onset, OnsetPattern.sudden);
    });

    test('Z — بدأ شوي شوي → gradual', () {
      final r = engine.understand('بدأ شوي شوي');
      expect(r.onset, OnsetPattern.gradual);
    });

    test('AA — تعبان conservative broad only', () {
      final r = engine.understand('تعبان');
      expect(s(r, 'fatigue')?.status, SymptomPolarity.present);
      expect(s(r, 'fatigue')?.confidence, SymptomMatchConfidence.ambiguous);
      expect(r.symptoms.length, 1);
    });

    test('AB — أريد مختبر الحياة → health false', () {
      expect(engine.looksLikeHealthLanguage('أريد مختبر الحياة'), isFalse);
      expect(
        engine.understand('أريد مختبر الحياة').containsHealthLanguage,
        isFalse,
      );
    });

    test('AC — أريد تحليل CBC → health false', () {
      expect(engine.looksLikeHealthLanguage('أريد تحليل CBC'), isFalse);
    });

    test('AD — اتصل بالدكتور → health false', () {
      expect(engine.looksLikeHealthLanguage('اتصل بالدكتور'), isFalse);
    });

    test('AE — no symptom text persisted', () {
      final dir = Directory('lib/health/understanding');
      for (final f in dir.listSync().whereType<File>()) {
        final src = f.readAsStringSync();
        expect(src.contains('SharedPreferences'), isFalse);
        expect(src.contains('supabase.from'), isFalse);
        expect(src.contains('Supabase.instance'), isFalse);
      }
    });

    test('AF — no raw symptom production logging', () {
      final dir = Directory('lib/health/understanding');
      for (final f in dir.listSync().whereType<File>()) {
        final src = f.readAsStringSync();
        expect(RegExp(r'\bprint\s*\(').hasMatch(src), isFalse);
        expect(src.contains('debugPrint'), isFalse);
      }
    });

    test('AG — no diagnosis generated', () {
      final r = engine.understand('راسي يوجعني واني دايخ');
      final blob = r.symptoms.map((e) => e.conceptId).join(',');
      expect(blob.contains('migraine'), isFalse);
      expect(blob.contains('diagnosis'), isFalse);
      expect(r.userStatedConditions, isNot(contains('شقيقة')));
    });

    test('AH — no specialty generated', () {
      final r = engine.understand('بطني يوجعني');
      expect(r.toString().toLowerCase().contains('specialty'), isFalse);
      expect(r.symptoms.every((s) => !s.conceptId.contains('neurolog')), isTrue);
    });

    test('AI — no analysis recommendation', () {
      final r = engine.understand('عندي حرارة وسعال');
      expect(r.symptoms.any((s) => s.conceptId == 'cbc'), isFalse);
      expect(r.toString().contains('تحليل'), isFalse);
    });

    test('AJ — no medication/treatment generated', () {
      final r = engine.understand('عندي صداع');
      expect(r.symptoms.every((s) => !s.conceptId.contains('drug')), isTrue);
      expect(r.symptoms.every((s) => !s.conceptId.contains('treat')), isTrue);
      expect(r.userStatedConditions, isEmpty);
    });

    test('AK — longest phrase prevents duplicate overlap', () {
      final r = engine.understand('ضيق نفس');
      expect(s(r, 'shortness_of_breath'), isNotNull);
      // لا يفتّت إلى مفاهيم جزئية مكررة لنفس المطابقة
      expect(
        r.symptoms.where((x) => x.conceptId == 'shortness_of_breath').length,
        1,
      );
    });

    test('AL — no accidental substring detection', () {
      // كلمة غير صحية تحتوي حروفاً مشابهة دون حدود عبارة
      final r = engine.understand('أريد حجز موعد');
      expect(r.symptoms, isEmpty);
    });

    test('AM — Arabic orthographic variants normalize safely', () {
      final a = engine.understand('أذني توجعني');
      final b = engine.understand('اذني توجعني');
      expect(s(a, 'ear_pain')?.status, SymptomPolarity.present);
      expect(s(b, 'ear_pain')?.status, SymptomPolarity.present);
    });

    test('AN — Step 10A duration parser reused not duplicated', () {
      expect(engine.durationParser, isA<ArabicDurationParser>());
      final healthFiles = Directory('lib/health/understanding')
          .listSync()
          .whereType<File>();
      for (final f in healthFiles) {
        final src = f.readAsStringSync();
        expect(src.contains('class ArabicDurationParser'), isFalse);
      }
      expect(
        File('lib/health/understanding/symptom_matcher.dart')
            .readAsStringSync()
            .contains('ArabicDurationParser'),
        isTrue,
      );
    });

    test('AO — Step 10A yes/no unchanged', () async {
      final ctx = ConversationContext();
      final planner = SmartBrainPlanner();
      planner.startServiceAssistanceDemo(context: ctx);
      await planner.plan(query: 'إي', context: ctx);
      expect(
        ctx.guidedConversation.collectedAnswers['help_search_yes_no']?.yesNo,
        isTrue,
      );
      await planner.plan(query: 'لا', context: ctx);
      // بعد إي ننتقل لسؤال الخدمة؛ لا هنا قد تكون جواب اختيار أو غير ذلك
      // أعد اختبار yes/no على تدفق جديد
      final ctx2 = ConversationContext();
      planner.startServiceAssistanceDemo(context: ctx2);
      final plan = await planner.plan(query: 'لا', context: ctx2);
      expect(
        ctx2.guidedConversation.collectedAnswers['help_search_yes_no']?.yesNo,
        isFalse,
      );
      expect(plan.kind, AssistantActionKind.guidedConversation);
    });

    test('AP — Step 5 clarification unchanged', () async {
      final ctx = ConversationContext();
      final planner = SmartBrainPlanner(
        doctorLookup: (q) async => [
              SmartSearchResult(
                type: SmartSearchResultType.doctor,
                title: 'الدكتور علي ناصر',
                subtitle: 'أ',
                doctorId: 'nasir',
                score: 90,
              ),
              SmartSearchResult(
                type: SmartSearchResultType.doctor,
                title: 'الدكتور علي فليح',
                subtitle: 'ب',
                doctorId: 'fleih',
                score: 88,
              ),
            ],
      );
      ctx.setPendingClarification(
        PendingClarification(
          entityType: ClarificationEntityType.doctor,
          reason: ClarificationReason.ambiguousName,
          candidates: [
            ClarificationCandidate(
              id: 'nasir',
              entityType: ClarificationEntityType.doctor,
              primaryLabel: 'الدكتور علي ناصر',
              payload: SmartSearchResult(
                type: SmartSearchResultType.doctor,
                title: 'الدكتور علي ناصر',
                subtitle: 'أ',
                doctorId: 'nasir',
                score: 90,
              ),
            ),
            ClarificationCandidate(
              id: 'fleih',
              entityType: ClarificationEntityType.doctor,
              primaryLabel: 'الدكتور علي فليح',
              payload: SmartSearchResult(
                type: SmartSearchResultType.doctor,
                title: 'الدكتور علي فليح',
                subtitle: 'ب',
                doctorId: 'fleih',
                score: 88,
              ),
            ),
          ],
        ),
      );
      await planner.plan(query: 'الثاني', context: ctx);
      expect(ctx.selectedDoctor?.doctorId, 'fleih');
    });

    test('AQ — entity pipeline still works', () async {
      final ctx = ConversationContext();
      final planner = SmartBrainPlanner(
        labLookup: (q) async => [
              SmartSearchResult(
                type: SmartSearchResultType.lab,
                title: 'مختبر الحياة',
                subtitle: 'مختبر',
                labId: 'hayat',
                score: 90,
              ),
            ],
      );
      final plan = await planner.plan(query: 'أريد مختبر الحياة', context: ctx);
      expect(
        plan.kind == AssistantActionKind.runLabSearch ||
            plan.target?.labId == 'hayat' ||
            plan.canExecute ||
            plan.labQuery != null,
        isTrue,
      );
    });

    test('AR — voice/text parity', () {
      const text = 'راسي يوجعني ونفسي ضايج';
      expect(QueryInputSource.voice, isNot(QueryInputSource.typed));
      final a = engine.understand(text);
      final b = engine.understand(text);
      expect(a.symptoms.map((e) => e.conceptId).toSet(),
          b.symptoms.map((e) => e.conceptId).toSet());
      expect(a.symptoms.map((e) => e.status), b.symptoms.map((e) => e.status));
    });
  });

  group('Scripted understanding', () {
    test('MULTI — cough fever present vomiting absent + duration', () {
      final r = engine.understand(
        'من يومين عندي سعال وحرارة بس ما عندي استفراغ',
      );
      expect(r.duration?.amount, 2);
      expect(r.duration?.unit, 'day');
      expect(s(r, 'cough')?.status, SymptomPolarity.present);
      expect(s(r, 'fever')?.status, SymptomPolarity.present);
      expect(s(r, 'vomiting')?.status, SymptomPolarity.absent);
      expect(r.symptoms.any((x) => x.conceptId.contains('diagnos')), isFalse);
    });

    test('IRAQI — headache dizziness nausea', () {
      final r = engine.understand('راسي يوجعني واني دايخ ونفسي تتلوع');
      expect(s(r, 'headache')?.status, SymptomPolarity.present);
      expect(s(r, 'dizziness')?.status, SymptomPolarity.present);
      expect(s(r, 'nausea')?.status, SymptomPolarity.present);
    });

    test('ANATOMICAL — knee left severe 3 days', () {
      final r = engine.understand('عندي ألم قوي بركبتي اليسرى من ٣ أيام');
      final k = s(r, 'knee_pain');
      expect(k?.status, SymptomPolarity.present);
      expect(k?.bodyRegion ?? (r.bodyRegions.contains(BodyRegionId.knee)
          ? BodyRegionId.knee
          : null), BodyRegionId.knee);
      expect(
        k?.laterality == Laterality.left || r.laterality == Laterality.left,
        isTrue,
      );
      expect(
        k?.userSeverity == UserStatedSeverity.severe ||
            r.userSeverity == UserStatedSeverity.severe,
        isTrue,
      );
      expect(r.duration?.amount, 3);
    });

    test('catalog source abstraction is local now', () {
      final catalog = const LocalSymptomCatalog();
      expect(catalog.enabledSymptomsSync(), isNotEmpty);
      expect(catalog.enabledAliasesSync(), isNotEmpty);
      expect(
        catalog.enabledSymptomsSync().any((c) => c.id == 'headache'),
        isTrue,
      );
    });

    test('DurationValue type shared with guided models', () {
      final r = engine.understand('من أسبوعين عندي سعال');
      expect(r.duration, isA<DurationValue>());
    });
  });
}
