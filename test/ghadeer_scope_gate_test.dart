import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/ghadeer_scope_gate.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

/// مرحلة 1 — قفل نطاق الغدير + corpus جمل قابلة للقياس.
void main() {
  final fixtureFile = File(
    'test/fixtures/ghadeer_scope_utterances.json',
  );

  late List<Map<String, dynamic>> rows;

  setUpAll(() {
    expect(fixtureFile.existsSync(), isTrue, reason: fixtureFile.path);
    final decoded = jsonDecode(fixtureFile.readAsStringSync()) as List<dynamic>;
    rows = decoded.cast<Map<String, dynamic>>();
    expect(rows.length, greaterThanOrEqualTo(40));
  });

  group('GhadeerScopeGate', () {
    test('رسالة الرفض عراقية وثابتة', () {
      expect(GhadeerScopeGate.outOfScopeMessage, contains('منصة الغدير'));
      expect(GhadeerScopeGate.outOfScopeMessage, contains('الأطباء'));
      expect(GhadeerScopeGate.outOfScopeMessage, contains('الصيدليات'));
      expect(GhadeerScopeGate.outOfScopeMessage, contains('الأشعة'));
    });

    test('corpus: خارج النطاق يُرفض، داخل المنصة لا يُرفض بالبوابة وحدها', () {
      final resolver = RuleBasedIntentResolver();
      for (final row in rows) {
        final q = row['query'] as String;
        final expectKind = row['expect'] as String;
        final id = row['id'] as String;
        final intent = resolver.resolve(q);
        final refuse = GhadeerScopeGate.shouldRefuse(query: q, intent: intent);
        if (expectKind == 'out_of_scope') {
          expect(
            refuse || GhadeerScopeGate.isOutOfScope(q),
            isTrue,
            reason: '$id · $q · intent=${intent.intent}',
          );
        } else {
          // منصة: إما نية مملوكة أو إشارة منصة أو اسم قصير مسموح.
          expect(
            GhadeerScopeGate.isPlatformOwnedIntent(intent.intent) ||
                GhadeerScopeGate.hasPlatformCue(q) ||
                !GhadeerScopeGate.isOutOfScope(q),
            isTrue,
            reason: '$id · $q · intent=${intent.intent}',
          );
        }
      }
    });
  });

  group('SmartBrainPlanner — قفل النطاق (clinicalEnabled=false)', () {
    SmartBrainPlanner scoped() => SmartBrainPlanner(
          clinicalEnabled: false,
          doctorLookup: (_) async => const [],
          labLookup: (_) async => const [],
          radiologyLookup: (_) async => const [],
          packagesLookup: (_) async => const [],
          analysisLookup: (_) async => const [],
          activePackagesLookup: ({String? labId, String? nameQuery}) async =>
              const [],
          discountedPackagesLookup: ({String? labId}) async => const [],
        );

    test('كأس العالم → رفض مهذّب بلا بحث عام', () async {
      final ctx = ConversationContext();
      final plan = await scoped().plan(
        query: 'من فاز بكأس العالم 2014؟',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.showMessage);
      expect(plan.canExecute, isFalse);
      expect(plan.message, GhadeerScopeGate.outOfScopeMessage);
      expect(plan.kind, isNot(AssistantActionKind.runGeneralSearch));
    });

    test('الطقس / الدولار → رفض', () async {
      for (final q in const ['شلون الطقس اليوم', 'شنو سعر الدولار']) {
        final plan = await scoped().plan(
          query: q,
          context: ConversationContext(),
        );
        expect(plan.message, GhadeerScopeGate.outOfScopeMessage, reason: q);
        expect(plan.kind, AssistantActionKind.showMessage, reason: q);
      }
    });

    test('اريد طبيب اطفال → يبقى مسار منصة (اختصاص)', () async {
      final plan = await scoped().plan(
        query: 'اريد طبيب اطفال',
        context: ConversationContext(),
      );
      expect(plan.message, isNot(GhadeerScopeGate.outOfScopeMessage));
      expect(
        plan.kind == AssistantActionKind.runSpecialtySearch ||
            plan.kind == AssistantActionKind.runDoctorSearch ||
            plan.kind == AssistantActionKind.runGeneralSearch,
        isTrue,
        reason: 'kind=${plan.kind}',
      );
    });

    test('corpus out_of_scope عبر المخطِّط: لا runGeneralSearch', () async {
      final oos = rows.where((r) => r['expect'] == 'out_of_scope');
      for (final row in oos) {
        final q = row['query'] as String;
        final id = row['id'] as String;
        final plan = await scoped().plan(
          query: q,
          context: ConversationContext(),
        );
        // أعراض قد تمر لرسالة النطاق السريري — مقبولة كرفض بلا بحث.
        final refused = plan.kind == AssistantActionKind.showMessage &&
            (plan.message == GhadeerScopeGate.outOfScopeMessage ||
                plan.message == SmartBrainPlanner.scopedClinicalOffMessage);
        expect(refused, isTrue, reason: '$id · $q · msg=${plan.message}');
        expect(
          plan.kind,
          isNot(AssistantActionKind.runGeneralSearch),
          reason: id,
        );
      }
    });

    test('corpus platform: لا يُرفض برسالة خارج النطاق', () async {
      final plat = rows.where((r) => r['expect'] == 'platform');
      for (final row in plat) {
        final q = row['query'] as String;
        final id = row['id'] as String;
        final plan = await scoped().plan(
          query: q,
          context: ConversationContext(),
        );
        expect(
          plan.message,
          isNot(GhadeerScopeGate.outOfScopeMessage),
          reason: '$id · $q · kind=${plan.kind}',
        );
      }
    });
  });

  group('RuleBasedIntentResolver — خارج النطاق → unknown', () {
    final resolver = RuleBasedIntentResolver();

    test('كأس العالم ليس generalSearch', () {
      final r = resolver.resolve('من فاز بكأس العالم 2014؟');
      expect(r.intent, AssistantIntent.unknown);
    });
  });
}
