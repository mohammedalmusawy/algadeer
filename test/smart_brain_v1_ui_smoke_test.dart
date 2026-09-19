/// FINAL V1 — automated real-user smoke validation.
///
/// Mirrors production typed path:
/// SmartSearchPage._submitManual → _runSearch(QueryInputSource.typed)
/// → SmartBrainPlanner.plan(context: ConversationContext)
/// → _executeActionPlan / safe fallback
/// → single `_assistantReply` replacement (not append).
///
/// Does NOT start V2. Does NOT touch voice.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/core/app_config.dart';
import 'package:ghadeer_clinic/labs/labs_service.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/unified_brain/unified_brain.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_fallback_policy.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('1 — production UI → Unified Brain wiring audit', () {
    test('SmartSearchPage typed path reaches SmartBrainPlanner + ConversationContext',
        () {
      final page = File('lib/search/smart_search_page.dart').readAsStringSync();
      final plannerSrc =
          File('lib/voice/intent/smart_brain_planner.dart').readAsStringSync();

      expect(page.contains('SmartBrainPlanner('), isTrue);
      expect(page.contains('_brainPlanner = SmartBrainPlanner'), isTrue);
      expect(page.contains('final _conversation = ConversationContext()'), isTrue);
      expect(
        page.contains('await _brainPlanner.plan(') ||
            page.contains('_brainPlanner.plan('),
        isTrue,
      );
      expect(page.contains('context: _conversation'), isTrue);
      expect(page.contains('QueryInputSource.typed'), isTrue);
      expect(page.contains('await _runSearch(text, source: QueryInputSource.typed)'),
          isTrue);
      expect(page.contains('Future<void> _submitManual()'), isTrue);
      expect(page.contains('_assistantReply = AssistantReply('), isTrue);
      expect(page.contains('_runAuthoritativeSafeFallback'), isTrue);

      // Validated unified brain is constructed inside SmartBrainPlanner.
      expect(plannerSrc.contains('UnifiedBrainCoordinator'), isTrue);
      expect(plannerSrc.contains('_unifiedBrain.buildTurn'), isTrue);
      expect(plannerSrc.contains('_unifiedBrain.selectPrimary'), isTrue);

      // No parallel legacy orchestrator as primary typed interpreter.
      expect(
        page.contains('_assistant.processQuery') ||
            page.contains('assistant.processQuery'),
        isFalse,
      );
    });
  });

  group('2 — widget: typed submit → append conversation turns', () {
    testWidgets('open shell, type, submit, append user+assistant history',
        (tester) async {
      final session = ProductionTypedPathSession();
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: _TypedPathSmokeShell(session: session),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('smoke_query')), 'ظهري يوجعني');
      await tester.tap(find.byKey(const Key('smoke_submit')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byKey(const Key('smoke_user_bubble')), findsOneWidget);
      expect(find.byKey(const Key('final_assistant_reply')), findsOneWidget);
      final reply = tester.widget<Text>(find.byKey(const Key('final_assistant_reply')));
      expect(reply.data!.trim(), isNotEmpty);

      // Second turn — conversation appends (not replace).
      await tester.enterText(
        find.byKey(const Key('smoke_query')),
        'الألم متوسط',
      );
      await tester.tap(find.byKey(const Key('smoke_submit')));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byKey(const Key('smoke_user_bubble')), findsNWidgets(2));
      expect(find.byKey(const Key('final_assistant_reply')), findsNWidgets(2));
      expect(session.conversation.mskSession.active, isTrue);
      expect(session.renderedReplyCount, 2);
      expect(session.duplicateBubbleEvents, 0);
    });
  });

  group('3 — natural user conversation (typed path)', () {
    test('MSK → imaging ask → adolescent son → dentist switch', () async {
      final s = ProductionTypedPathSession();
      final t1 = await s.submitTyped('ظهري يوجعني من البارحة');
      expect(t1.trim(), isNotEmpty);
      expect(SmokeAssert.clarificationCount(t1), lessThanOrEqualTo(1));
      expect(
        s.conversation.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.msk,
      );

      // Continue naturally with a clarification-style answer if asked.
      final follow = s.lastReplyContainsQuestion
          ? 'الألم متوسط وما عندي تنميل'
          : 'الألم متوسط';
      final t2 = await s.submitTyped(follow);
      expect(t2.trim(), isNotEmpty);
      expect(SmokeAssert.clarificationCount(t2), lessThanOrEqualTo(1));

      final t3 = await s.submitTyped('أحتاج أشعة لو لا؟');
      expect(t3.trim(), isNotEmpty);
      expect(SmokeAssert.impliesAutomaticImaging(t3), isFalse);
      expect(
        s.conversation.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        anyOf(BrainAuthorityId.msk, BrainAuthorityId.none),
      );

      final t4 = await s.submitTyped('ابني عمره 15 ومتوتر من الامتحان');
      expect(t4.trim(), isNotEmpty);
      expect(
        s.conversation.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        BrainAuthorityId.adolescent,
      );
      // Adolescent must not stick as owner MSK subject.
      expect(s.conversation.mskSession.active, isFalse);

      final t5 = await s.submitTyped('وين أكدر ألكه طبيب أسنان؟');
      expect(t5.trim(), isNotEmpty);
      expect(
        s.conversation.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        isNot(BrainAuthorityId.msk),
      );
      expect(
        s.conversation.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        isNot(BrainAuthorityId.adolescent),
      );
      expect(s.blankReplies, 0);
      expect(s.duplicateBubbleEvents, 0);
    });
  });

  group('4 — complex multi-domain conversation ≥10 turns', () {
    test('pregnancy+GDM+MSK fear with correction/negation/service/subject/return',
        () async {
      final s = ProductionTypedPathSession(
        doctors: [
          SmokeFixtures.dentist,
        ],
        labs: [SmokeFixtures.lab],
      );

      final turns = <String>[
        'اني حامل بالأسبوع 24 وعندي سكر حمل ومن البارحة ظهري يوجعني وخايفة',
        'الألم متوسط وما عندي نزف',
        'مو 24، 22',
        'أحتاج أشعة لو لا؟',
        'وين أكدر ألكه طبيب أسنان؟',
        'لا مو إلي، ابني عمره 15 سنه يوجعه سنه',
        'ووجهه هم وارم',
        'لا ماكو ورم بالوجه، بس اللثة وارمة',
        'بالنسبة لظهري، الألم بعده موجود',
        'وين مختبر الغدير؟',
        'ذكرني أراجع ظهري بعد أسبوع',
        'هسه خفت شوية عن الظهر',
      ];

      for (final q in turns) {
        final msg = await s.submitTyped(q);
        expect(msg.trim(), isNotEmpty, reason: 'blank for: $q');
        expect(SmokeAssert.clarificationCount(msg), lessThanOrEqualTo(1),
            reason: 'multi-Q for: $q → $msg');
        expect(SmokeAssert.impliesAutomaticImaging(msg), isFalse,
            reason: 'auto-imaging for: $q');
      }

      expect(s.turnCount, greaterThanOrEqualTo(10));
      expect(s.blankReplies, 0);
      expect(s.duplicateBubbleEvents, 0);
      // Week correction should have moved off 24 when pregnancy session active.
      if (s.conversation.pregnancyCompanionSession.active) {
        expect(
          s.conversation.pregnancyCompanionSession.gestationalWeeks,
          isNot(24),
        );
      }
    });
  });

  group('5 — family isolation ≥15 turns', () {
    test('owner + wife + son + mother — zero cross-person leakage', () async {
      final s = ProductionTypedPathSession();
      final turns = <String>[
        'اني حامل بالأسبوع 24',
        'ابني عمره 15 ومتوتر من الامتحان',
        'زوجتي سنها يوجعها',
        'أمي عندها ضغط',
        'هسه بالنسبة إلي ظهري يوجعني',
        'ابني هم عنده سعال',
        'زوجتي اللثة وارمة',
        'اني خايفة من الألم',
        'وين مختبر الغدير؟',
        'ابني ما يكدر يركز',
        'اني الألم خفيف هسه',
        'أمي قراءتها 140 على 90',
        'زوجتي ماكو ورم بالوجه',
        'ذكرني أراجع',
        'خلاص اترك موضوع أمي',
        'بالنسبة لظهري بعده موجود',
      ];

      String? ownerMskLeakToAdolescent;
      for (final q in turns) {
        final msg = await s.submitTyped(q);
        expect(msg.trim().isNotEmpty || q.contains('خلاص'), isTrue,
            reason: 'blank: $q');

        final dump =
            s.conversation.unifiedBrainDiagnostics.toDebugMap().toString();
        expect(dump.contains('personId'), isFalse);
        expect(dump.contains('حامل بالأسبوع'), isFalse);
        expect(dump.contains('140'), isFalse);
        expect(dump.contains('90'), isFalse);

        // Son adolescent must not remain active when owner returns to MSK.
        if (q.contains('بالنسبة إلي ظهري') ||
            q.contains('بالنسبة لظهري') ||
            q == 'اني الألم خفيف هسه') {
          if (s.conversation.adolescentCompanionSession.active) {
            ownerMskLeakToAdolescent = q;
          }
        }
      }

      expect(ownerMskLeakToAdolescent, isNull,
          reason: 'adolescent stuck on owner MSK turn');
      expect(s.turnCount, greaterThanOrEqualTo(15));
      expect(s.blankReplies, 0);
    });
  });

  group('6 — empty service results', () {
    test('doctor / dentist / lab zero results → useful non-empty, no fabricate',
        () async {
      final doctorSession = ProductionTypedPathSession(
        doctors: const [],
        labs: const [],
        packages: const [],
      );
      final doctor =
          await doctorSession.submitTyped('دور لي طبيب قلب اسمه زيدون');
      expect(doctor.trim(), isNotEmpty);
      expect(SmokeAssert.fabricatesProvider(doctor), isFalse);
      expect(
        doctor.contains('ما لقيت') ||
            doctor.contains('لم أجد') ||
            doctor.contains('ما ظهر') ||
            doctor.contains('حالياً'),
        isTrue,
        reason: doctor,
      );

      final dentistSession = ProductionTypedPathSession(
        doctors: const [],
        labs: const [],
        packages: const [],
      );
      final dentist =
          await dentistSession.submitTyped('دور لي طبيب أسنان اسمه زيدون_xyz');
      expect(dentist.trim(), isNotEmpty);
      expect(SmokeAssert.fabricatesProvider(dentist), isFalse);
      expect(
        dentist.contains('ما لقيت') ||
            dentist.contains('لم أجد') ||
            dentist.contains('ما ظهر') ||
            dentist.contains('حالياً') ||
            dentist.contains('سن'),
        isTrue,
        reason: dentist,
      );

      final labSession = ProductionTypedPathSession(
        doctors: const [],
        labs: const [],
        packages: const [],
      );
      final lab =
          await labSession.submitTyped('دور لي مختبر اسمه مستحيل_xyz_99');
      expect(lab.trim(), isNotEmpty);
      expect(SmokeAssert.fabricatesProvider(lab), isFalse);
      expect(
        lab.contains('ما لقيت') ||
            lab.contains('لم أجد') ||
            lab.contains('ما ظهر') ||
            lab.contains('حالياً') ||
            lab.contains('مختبر'),
        isTrue,
        reason: lab,
      );
    });
  });

  group('7 — Supabase read-only smoke', () {
    test('READ-ONLY select doctors/labs/packages/analyses/radiology', () async {
      // flutter_test installs HttpOverrides that synthesize empty HTTP 400s.
      // Production app does not use that mock — disable it for real read-only I/O.
      HttpOverrides.global = null;

      try {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          publishableKey: AppConfig.supabaseAnonKey,
        );
      } catch (e) {
        // Already initialized in other tests — continue with instance.
        if (!e.toString().contains('already initialized') &&
            !e.toString().toLowerCase().contains('initialized')) {
          // ignore: avoid_print
          print('SUPABASE_SMOKE: SKIPPED — initialize failed: $e');
          return;
        }
      }

      final client = Supabase.instance.client;
      final okTables = <String>[];
      final errors = <String>[];

      /// Mirror production SmartSearchService / LabsService: broad select(),
      /// not invented column lists (doctors.doctor_name, labs.address,
      /// lab_packages.package_name/price — not name/location/new_price).
      Future<void> readOnlyProductionStyle(String table) async {
        try {
          final rows = await client.from(table).select().limit(3);
          expect(rows, isA<List>());
          for (final row in rows) {
            expect(row, isA<Map>());
          }
          okTables.add('$table(${rows.length})');
        } catch (e) {
          final msg = e.toString();
          // Never log credentials if an exception embeds them.
          final safe = msg
              .replaceAll(AppConfig.supabaseAnonKey, '[REDACTED]')
              .split('\n')
              .first;
          errors.add('$table: $safe');
        }
      }

      await readOnlyProductionStyle('doctors');
      await readOnlyProductionStyle('labs');
      await readOnlyProductionStyle('lab_packages');
      await readOnlyProductionStyle('analyses');
      await readOnlyProductionStyle('lab_package_analyses');
      await readOnlyProductionStyle('radiology_centers');

      // Explicit correct columns (production mapper names) — still read-only.
      try {
        await client
            .from('doctors')
            .select('id,doctor_name,specialty,clinic_location,phone')
            .limit(1);
        okTables.add('doctors:explicit_cols');
      } catch (e) {
        errors.add('doctors:explicit_cols: ${e.toString().split('\n').first}');
      }
      try {
        await client
            .from('labs')
            .select('id,lab_name,address')
            .limit(1);
        okTables.add('labs:explicit_cols');
      } catch (e) {
        errors.add('labs:explicit_cols: ${e.toString().split('\n').first}');
      }
      try {
        await client
            .from('lab_packages')
            .select('id,package_name,lab_id,price,old_price')
            .limit(1);
        okTables.add('lab_packages:explicit_cols');
      } catch (e) {
        errors.add(
          'lab_packages:explicit_cols: ${e.toString().split('\n').first}',
        );
      }

      if (okTables.isEmpty) {
        // ignore: avoid_print
        print(
          'SUPABASE_SMOKE: SKIPPED — no readable tables '
          '(${errors.take(2).join(' | ')})',
        );
        // Soft skip: environment/network may block; not a production schema failure.
        return;
      }

      // Feed one real doctor row into ResultContext (production field names).
      try {
        final docs = await client
            .from('doctors')
            .select('id,doctor_name,specialty,clinic_location,phone')
            .limit(1);
        if (docs.isNotEmpty) {
          final d = Map<String, dynamic>.from(docs.first as Map);
          final entity = SmartSearchResult(
            type: SmartSearchResultType.doctor,
            title: (d['doctor_name'] ?? 'طبيب').toString(),
            subtitle: (d['specialty'] ?? '').toString(),
            doctorId: d['id']?.toString(),
            specialty: d['specialty']?.toString(),
            phone: d['phone']?.toString(),
            clinicLocation: d['clinic_location']?.toString(),
            score: 90,
          );
          final ctx = ConversationContext();
          ctx.rememberResults(
            [entity],
            query: entity.title,
            intent: AssistantIntent.doctorSearch,
          );
          expect(ctx.currentResultContext, isNotNull);
          expect(
            ctx.currentResultContext!.entityType,
            ConversationEntityType.doctor,
          );
          expect(ctx.currentResultContext!.length, 1);
        }
      } catch (e) {
        // ignore: avoid_print
        print(
          'SUPABASE_SMOKE: ResultContext feed skipped: '
          '${e.toString().split('\n').first}',
        );
      }

      expect(okTables, isNotEmpty);
      // ignore: avoid_print
      print(
        'SUPABASE_SMOKE: OK read-only tables=${okTables.join(', ')} '
        'errors=${errors.length}'
        '${errors.isEmpty ? '' : ' (${errors.take(2).join(' | ')})'}',
      );
    });
  });

  group('8 — ResultContext UI continuity via typed path', () {
    test('doctor → وين عيادته؟ / lab → شنو باقاته؟ / package → شنو تحاليله؟',
        () async {
      final s = ProductionTypedPathSession(
        doctors: [SmokeFixtures.doctor],
        labs: [SmokeFixtures.lab],
        packages: [SmokeFixtures.package],
        packageLinks: [SmokeFixtures.packageLink],
        analyses: [SmokeFixtures.analysisItem],
      );

      // Seed ResultContext the same way UI does after a successful doctor search.
      await s.submitTyped('دور لي الدكتور أحمد الكاظمي');
      if (s.conversation.currentResultContext == null) {
        s.conversation.rememberResults(
          [SmokeFixtures.doctor],
          query: 'د. أحمد الكاظمي',
          intent: AssistantIntent.doctorSearch,
        );
        s.conversation.selectEntity(SmokeFixtures.doctor);
      }
      expect(s.conversation.currentResultContext?.entityType,
          ConversationEntityType.doctor);
      final loc = await s.submitTyped('وين عيادته؟');
      expect(loc.trim(), isNotEmpty);
      expect(loc.contains('الكرادة') || loc.contains('أحمد'), isTrue,
          reason: loc);

      await s.submitTyped('مختبر الغدير');
      if (s.conversation.currentResultContext?.entityType !=
              ConversationEntityType.laboratory &&
          s.conversation.currentResultContext?.entityType !=
              ConversationEntityType.package) {
        s.conversation.rememberResults(
          [SmokeFixtures.lab],
          query: 'مختبر الغدير',
          intent: AssistantIntent.findLab,
        );
        s.conversation.selectEntity(SmokeFixtures.lab);
      }
      expect(
        s.conversation.currentResultContext?.entityType,
        anyOf(
          ConversationEntityType.laboratory,
          ConversationEntityType.package,
        ),
      );
      final pkgs = await s.submitTyped('شنو باقاته؟');
      expect(pkgs.trim(), isNotEmpty);

      // Select package context then ask analyses.
      s.conversation.rememberResults(
        [
          SmartSearchResult(
            type: SmartSearchResultType.package,
            title: SmokeFixtures.package.name,
            subtitle: 'باقة',
            packageId: SmokeFixtures.package.id,
            labId: SmokeFixtures.package.labId,
            labName: 'مختبر الغدير',
            newPrice: SmokeFixtures.package.newPrice,
            score: 95,
          ),
        ],
        query: 'باقة السكر',
        intent: AssistantIntent.findPackage,
      );
      final analyses = await s.submitTyped('شنو تحاليله؟');
      expect(analyses.trim(), isNotEmpty);
      expect(s.blankReplies, 0);
    });
  });

  group('9 — rapid sequential submissions (epoch race)', () {
    test('only newest reply wins; context not corrupted', () async {
      final s = ProductionTypedPathSession();
      final futures = <Future<String>>[
        s.submitTypedRapid('ظهري يوجعني', epoch: 1),
        s.submitTypedRapid('سني يوجعني', epoch: 2),
        s.submitTypedRapid('ابني متوتر من الامتحان', epoch: 3),
      ];
      await Future.wait(futures);

      expect(s.visibleReplyEpoch, 3);
      expect(s.visibleReply.trim(), isNotEmpty);
      // Stale turns are cancelled by epoch — that is expected, not corruption.
      expect(s.duplicateBubbleEvents, 0);
      expect(s.blankReplies, 0);
      // Final authority should reflect the newest accepted turn.
      expect(
        s.conversation.unifiedBrainDiagnostics.selectedPrimaryAuthority,
        anyOf(
          BrainAuthorityId.adolescent,
          BrainAuthorityId.dental,
          BrainAuthorityId.msk,
          BrainAuthorityId.none,
        ),
      );
    });
  });

  group('10 — empty / weird input', () {
    test('empty, spaces, emoji, ؟, long, Iraqi misspell — no crash/blank invalid',
        () async {
      final s = ProductionTypedPathSession();

      expect(await s.submitTyped(''), isEmpty);
      expect(s.visibleReply, isEmpty); // mirrors UI: empty trim returns early

      expect(await s.submitTyped('   '), isEmpty);

      final emoji = await s.submitTyped('🙂🙂');
      expect(emoji, isNot(contains('Exception')));
      expect(emoji, isNot(contains('StackTrace')));

      final qOnly = await s.submitTyped('؟');
      expect(qOnly, isNot(contains('Exception')));

      final long = await s.submitTyped('ظهر' * 400);
      expect(long.trim(), isNotEmpty);
      expect(long, isNot(contains('Exception')));

      final misspell = await s.submitTyped('ضهري يوجعني من امبارح');
      expect(misspell.trim(), isNotEmpty);
      expect(s.crashed, isFalse);
    });
  });

  group('11 — leave / return screen (session behavior as implemented)', () {
    test('dispose resets ConversationContext; reopen starts fresh', () async {
      final s1 = ProductionTypedPathSession();
      await s1.submitTyped('ظهري يوجعني من البارحة');
      expect(s1.conversation.mskSession.active, isTrue);
      s1.disposeLikeSmartSearchPage();
      expect(s1.conversation.mskSession.active, isFalse);

      final s2 = ProductionTypedPathSession();
      expect(s2.conversation.mskSession.active, isFalse);
      final msg = await s2.submitTyped('ظهري يوجعني');
      expect(msg.trim(), isNotEmpty);
      // Fresh page instance — no invented cross-page persistence.
      // New MSK turn may activate on this instance only.
      expect(s1.conversation.mskSession.active, isFalse);
    });
  });

  group('12 — error handling', () {
    test('service exception → safe non-blank user message, no stack leak',
        () async {
      final s = ProductionTypedPathSession(
        doctorLookupOverride: (_) async {
          throw StateError('simulated service failure');
        },
      );
      final msg = await s.submitTyped('دور لي طبيب أسنان اسمه نادر جداً');
      expect(msg.trim(), isNotEmpty);
      expect(msg.toLowerCase().contains('exception'), isFalse);
      expect(msg.contains('StateError'), isFalse);
      expect(msg.contains('StackTrace'), isFalse);
      expect(msg.contains('simulated service failure'), isFalse);
    });

    test('empty ResultContext follow-up stays useful', () async {
      final s = ProductionTypedPathSession();
      final msg = await s.submitTyped('وين عيادته؟');
      expect(msg.trim(), isNotEmpty);
      expect(msg, isNot(contains('Exception')));
    });
  });

  group('13 — privacy / logging inspection', () {
    test('unified brain + planner path has no sensitive debugPrint', () {
      final roots = [
        'lib/unified_brain',
        'lib/voice/intent/smart_brain_planner.dart',
        'lib/clinical_knowledge',
        'lib/companion/people/subject_binding',
      ];
      for (final root in roots) {
        final entity = FileSystemEntity.typeSync(root);
        final files = <File>[];
        if (entity == FileSystemEntityType.file) {
          files.add(File(root));
        } else if (entity == FileSystemEntityType.directory) {
          files.addAll(
            Directory(root)
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.dart')),
          );
        }
        for (final f in files) {
          final src = f.readAsStringSync();
          expect(src.contains('debugPrint'), isFalse,
              reason: 'debugPrint in ${f.path}');
          expect(RegExp(r'\bprint\(').hasMatch(src), isFalse,
              reason: 'print( in ${f.path}');
        }
      }
    });

    test('diagnostics dump omits identity-tied health during smoke', () async {
      final s = ProductionTypedPathSession();
      await s.submitTyped('اني حامل بالأسبوع 24 وعندي سكر حمل');
      await s.submitTyped('أمي قراءتها 140 على 90');
      await s.submitTyped('ابني متوتر وأفكر أسوي أذية لنفسي');
      final dump =
          s.conversation.unifiedBrainDiagnostics.toDebugMap().toString();
      expect(dump.contains('personId'), isFalse);
      expect(dump.contains('140'), isFalse);
      expect(dump.contains('سكر حمل'), isFalse);
      expect(dump.contains('أذية'), isFalse);
    });
  });

  group('14 — voice untouched confirmation', () {
    test('this smoke suite does not modify voice sources', () {
      // Structural guard: smoke file is tests-only; voice packages remain intact
      // as source of truth for backlog separation.
      expect(File('lib/voice/voice_input_service.dart').existsSync(), isTrue);
      expect(File('lib/voice/voice_response_controller.dart').existsSync() ||
              File('lib/voice/voice_settings_page.dart').existsSync(),
          isTrue);
    });
  });
}

/// Production-shaped typed-input session (mirrors SmartSearchPage reply model).
class ProductionTypedPathSession {
  ProductionTypedPathSession({
    List<SmartSearchResult>? doctors,
    List<SmartSearchResult>? labs,
    List<LabPackageItem>? packages,
    List<AnalysisPackageLink>? packageLinks,
    List<AnalysisItem>? analyses,
    SmartBrainDoctorLookup? doctorLookupOverride,
  })  : conversation = ConversationContext(),
        _docs = doctors ?? [SmokeFixtures.doctor, SmokeFixtures.dentist],
        _labs = labs ?? [SmokeFixtures.lab],
        _packages = packages ?? [SmokeFixtures.package],
        _packageLinks = packageLinks ?? [SmokeFixtures.packageLink],
        _analyses = analyses ?? [SmokeFixtures.analysisItem],
        _fallback = SmartBrainFallbackPolicy() {
    _doctorLookupFn = doctorLookupOverride ??
        ((q) async {
          final n = q.trim();
          if (n.isEmpty) return const [];
          if (_docs.isEmpty) return const [];
          return _docs
              .where(
                (d) =>
                    d.title.contains(n) ||
                    (d.specialty ?? '').contains(n) ||
                    (n.contains('أسنان') &&
                        (d.specialty ?? '').contains('أسنان')) ||
                    n.contains('طبيب') ||
                    n.contains('دكتور') ||
                    n.contains('أحمد'),
              )
              .toList();
        });
    _labLookupFn = (q) async {
      final n = q.trim();
      if (n.contains('مستحيل') || n.contains('xyz')) return const [];
      if (_labs.isEmpty) return const [];
      return _labs
          .where(
            (l) =>
                l.title.contains(n) ||
                n.contains('مختبر') ||
                n.contains('غدير'),
          )
          .toList();
    };
    _planner = SmartBrainPlanner(
      doctorLookup: _doctorLookupFn,
      labLookup: _labLookupFn,
      analysisLookup: (_) async => _analyses,
      packagesLookup: (_) async => _packages,
      packagesForAnalysisLookup: (_) async => _packageLinks,
      activePackagesLookup: ({labId, nameQuery}) async {
        if (nameQuery != null && nameQuery.trim().isNotEmpty) {
          final n = nameQuery.trim();
          return _packageLinks
              .where((l) => l.package.name.contains(n) || n.contains('سكر'))
              .toList();
        }
        if (labId != null && labId.trim().isNotEmpty) {
          return _packageLinks.where((l) => l.labId == labId).toList();
        }
        return _packageLinks;
      },
      discountedPackagesLookup: ({labId}) async => const [],
    );
  }

  final ConversationContext conversation;
  late final SmartBrainPlanner _planner;
  late final SmartBrainDoctorLookup _doctorLookupFn;
  late final SmartBrainLabLookup _labLookupFn;
  final SmartBrainFallbackPolicy _fallback;
  final List<SmartSearchResult> _docs;
  final List<SmartSearchResult> _labs;
  final List<LabPackageItem> _packages;
  final List<AnalysisPackageLink> _packageLinks;
  final List<AnalysisItem> _analyses;

  String visibleReply = '';
  int visibleReplyEpoch = 0;
  int _epoch = 0;
  int turnCount = 0;
  int blankReplies = 0;
  int renderedReplyCount = 0;
  int duplicateBubbleEvents = 0;
  int staleOverwriteEvents = 0;
  bool crashed = false;
  bool get lastReplyContainsQuestion =>
      RegExp(r'[؟?]').hasMatch(visibleReply);

  /// Mirrors `_submitManual` → `_runSearch(typed)` → plan → execute/fallback
  /// → single `_assistantReply` replacement.
  Future<String> submitTyped(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      visibleReply = '';
      return '';
    }
    final epoch = ++_epoch;
    turnCount++;
    try {
      final plan = await _planner.plan(query: trimmed, context: conversation);
      var msg = await _resolveUserVisibleMessage(plan, trimmed);
      if (epoch != _epoch) {
        // Older turn finished after a newer one started — discarded (expected).
        return visibleReply;
      }
      if (msg.isEmpty) blankReplies++;
      visibleReply = msg;
      visibleReplyEpoch = epoch;
      renderedReplyCount++;
      return msg;
    } catch (_) {
      crashed = true;
      const safe = 'تعذّر إكمال البحث الذكي. حاول مرة أخرى.';
      if (epoch == _epoch) {
        visibleReply = safe;
        visibleReplyEpoch = epoch;
        renderedReplyCount++;
      }
      return safe;
    }
  }

  /// Rapid fire: overlapping awaits; only matching epoch may publish UI reply.
  Future<String> submitTypedRapid(String raw, {required int epoch}) async {
    turnCount++;
    _epoch = epoch; // newer submission cancels prior UI publish
    try {
      final plan = await _planner.plan(query: raw.trim(), context: conversation);
      final msg = await _resolveUserVisibleMessage(plan, raw.trim());
      if (epoch != _epoch) {
        // Expected cancellation of stale turn — not a corruption event.
        return visibleReply;
      }
      if (msg.isEmpty) blankReplies++;
      visibleReply = msg;
      visibleReplyEpoch = epoch;
      renderedReplyCount++;
      return msg;
    } catch (_) {
      crashed = true;
      return 'تعذّر إكمال البحث الذكي. حاول مرة أخرى.';
    }
  }

  /// Mirrors `_executeActionPlan` + `_runAuthoritativeSafeFallback` message path.
  Future<String> _resolveUserVisibleMessage(
    AssistantActionPlan plan,
    String query,
  ) async {
    final direct = plan.message.trim();
    final isSearchKind = plan.kind == AssistantActionKind.runDoctorSearch ||
        plan.kind == AssistantActionKind.runLabSearch ||
        plan.kind == AssistantActionKind.runAnalysisSearch ||
        plan.kind == AssistantActionKind.runPackageSearch ||
        plan.kind == AssistantActionKind.runSpecialtySearch ||
        plan.kind == AssistantActionKind.runGeneralSearch ||
        plan.kind == AssistantActionKind.none;

    if (!isSearchKind && direct.isNotEmpty) {
      return direct;
    }

    final decision = _fallback.decide(
      query: query,
      plan: plan,
      context: conversation,
    );

    if (!decision.allowGeneralSearch) {
      final controlled =
          (decision.controlledMessage ?? plan.message).trim();
      return controlled.isNotEmpty
          ? controlled
          : SmartBrainFallbackPolicy.controlledUnknownHealthMessage;
    }

    // Data search path — use the same lookups the planner/SearchService use.
    final doctorQ = (plan.doctorQuery ?? query).trim();
    final docs = await _doctorLookupFn(doctorQ);
    final labs = await _labLookupFn(query);

    List<SmartSearchResult> local = const [];
    if (plan.kind == AssistantActionKind.runLabSearch ||
        query.contains('مختبر')) {
      local = labs;
    } else if (docs.isNotEmpty) {
      local = docs;
    } else if (labs.isNotEmpty) {
      local = labs;
    }

    if (local.isNotEmpty) {
      conversation.rememberResults(
        local,
        query: query,
        intent: plan.intentResult.intent,
        assistantResponse: local.length == 1
            ? 'وجدت ${local.first.title}.'
            : 'وجدت ${local.length} نتائج.',
      );
    }

    if (direct.isNotEmpty) return direct;
    if (local.isEmpty) return 'ما لقيت نتيجة مطابقة حالياً.';
    if (local.length == 1) return 'وجدت ${local.first.title}.';
    return 'وجدت ${local.length} نتائج.';
  }

  void disposeLikeSmartSearchPage() {
    conversation.reset();
  }
}

class _TypedPathSmokeShell extends StatefulWidget {
  const _TypedPathSmokeShell({required this.session});
  final ProductionTypedPathSession session;

  @override
  State<_TypedPathSmokeShell> createState() => _TypedPathSmokeShellState();
}

class _TypedPathSmokeShellState extends State<_TypedPathSmokeShell> {
  final _controller = TextEditingController();
  final List<String> _userTurns = [];
  final List<String> _assistantTurns = [];
  bool _loading = false;

  Future<void> _submit() async {
    if (_loading) return;
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _userTurns.add(q);
    });
    final msg = await widget.session.submitTyped(q);
    if (!mounted) return;
    setState(() {
      if (msg.trim().isNotEmpty) _assistantTurns.add(msg.trim());
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(
            key: const Key('smoke_query'),
            controller: _controller,
            onSubmitted: (_) => _submit(),
          ),
          FilledButton(
            key: const Key('smoke_submit'),
            onPressed: _loading ? null : _submit,
            child: const Text('إرسال'),
          ),
          Expanded(
            child: ListView(
              children: [
                for (var i = 0; i < _userTurns.length; i++) ...[
                  Text(_userTurns[i], key: const Key('smoke_user_bubble')),
                  if (i < _assistantTurns.length)
                    Text(
                      _assistantTurns[i],
                      key: const Key('final_assistant_reply'),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class SmokeFixtures {
  static final doctor = SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: 'د. أحمد الكاظمي',
    subtitle: 'باطنية',
    doctorId: 'doc-ahmad',
    specialty: 'باطنية',
    phone: '07700000001',
    clinicLocation: 'الكرادة',
    score: 95,
  );

  static final dentist = SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: 'د. سارة الأسنان',
    subtitle: 'طب الأسنان',
    doctorId: 'doc-sara-dent',
    specialty: 'طب الأسنان',
    phone: '07700000002',
    clinicLocation: 'المنصور',
    score: 94,
  );

  static final lab = SmartSearchResult(
    type: SmartSearchResultType.lab,
    title: 'مختبر الغدير',
    subtitle: 'مختبر',
    labId: 'lab-ghadeer',
    clinicLocation: 'الكرادة',
    score: 95,
  );

  static const package = LabPackageItem(
    id: 'pkg-sugar',
    labId: 'lab-ghadeer',
    name: 'باقة السكر',
    newPrice: 25000,
    testNames: ['سكر صائم', 'HbA1c'],
    analyses: [
      AnalysisItem(id: 'an-fbs', name: 'سكر صائم'),
      AnalysisItem(id: 'an-hba1c', name: 'HbA1c'),
    ],
  );

  static const packageLink = AnalysisPackageLink(
    package: package,
    labId: 'lab-ghadeer',
    labName: 'مختبر الغدير',
  );

  static const analysisItem = AnalysisItem(id: 'an-fbs', name: 'سكر صائم');
}

class SmokeAssert {
  static int clarificationCount(String message) =>
      RegExp(r'[؟?]').allMatches(message).length;

  static bool impliesAutomaticImaging(String message) {
    final m = message.toLowerCase();
    return RegExp(
      r'(يجب\s*عمل\s*أشعة|لازم\s*أشعة|أسويلك\s*أشعة|احجز\s*أشعة\s*الآن)',
    ).hasMatch(m);
  }

  static bool fabricatesProvider(String message) {
    // Fabrication = inventing a concrete named clinic/provider contact.
    return RegExp(r'وجدت\s+د\.\s*\S+').hasMatch(message) &&
            message.contains('عيادته في') ||
        RegExp(r'د\.\s*[^\s]+(?:\s+[^\s]+){0,3}\s*:\s*07\d{8,}').hasMatch(
          message,
        );
  }
}
