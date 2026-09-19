import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/voice/context_resolver.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';

SmartSearchResult _doc(
  String id,
  String title, {
  int score = 80,
  String? location,
  String? phone,
  String? whatsapp,
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: title,
    subtitle: 'اختصاص',
    doctorId: id,
    score: score,
    clinicLocation: location,
    phone: phone,
    whatsapp: whatsapp,
  );
}

void main() {
  late ConversationContext ctx;
  const resolver = ContextResolver();

  setUp(() {
    ctx = ConversationContext();
  });

  group('ContextResolver Step 3', () {
    test('TEST 1 — الثاني selects B', () {
      final a = _doc('a', 'Doctor A');
      final b = _doc('b', 'Doctor B');
      final c = _doc('c', 'Doctor C');
      ctx.rememberResults([a, b, c], query: 'طبيب اطفال');

      final r = resolver.resolve('الثاني', ctx);
      expect(r.status, ContextResolutionStatus.selectResult);
      expect(r.target?.doctorId, 'b');
      expect(ctx.selectedEntity?.doctorId, 'b');
      expect(ctx.activeEntityType, ConversationEntityType.doctor);
    });

    test('TEST 2 — الأخير selects last', () {
      final a = _doc('a', 'A');
      final b = _doc('b', 'B');
      ctx.rememberResults([a, b]);
      final r = resolver.resolve('الأخير', ctx);
      expect(r.target?.doctorId, 'b');
    });

    test('TEST 3 — الثالث out of range on 2 results', () {
      ctx.rememberResults([_doc('a', 'A'), _doc('b', 'B')]);
      final r = resolver.resolve('الثالث', ctx);
      expect(r.status, ContextResolutionStatus.selectionOutOfRange);
      expect(ctx.selectedEntity, isNull);
      expect(r.message, contains('طبيبين'));
    });

    test('TEST 4 — الثاني without previous results', () {
      final r = resolver.resolve('الثاني', ctx);
      expect(r.status, ContextResolutionStatus.noPreviousResults);
      expect(ctx.selectedEntity, isNull);
      expect(r.message, contains('نتائج سابقة'));
    });

    test('TEST 5 — وين عيادته؟ uses selected location', () {
      final b = _doc('b', 'Doctor B', location: 'الكرادة');
      ctx.rememberResults([_doc('a', 'A'), b, _doc('c', 'C')]);
      resolver.resolve('الثاني', ctx);

      final r = resolver.resolve('وين عيادته؟', ctx);
      expect(r.status, ContextResolutionStatus.showLocation);
      expect(r.intent, AssistantIntent.showLocation);
      expect(r.target?.doctorId, 'b');
      expect(r.message, contains('الكرادة'));
    });

    test('TEST 6 — اتصل بيه', () {
      final b = _doc('b', 'B', phone: '07701234567');
      ctx.rememberResults([_doc('a', 'A'), b]);
      resolver.resolve('الثاني', ctx);

      final r = resolver.resolve('اتصل بيه', ctx);
      expect(r.status, ContextResolutionStatus.callDoctor);
      expect(r.intent, AssistantIntent.callDoctor);
      expect(r.target?.doctorId, 'b');
      expect(ctx.pendingAction, 'call');
    });

    test('TEST 7 — دزله واتساب', () {
      final b = _doc('b', 'B', whatsapp: '07701234567');
      ctx.rememberResults([_doc('a', 'A'), b]);
      resolver.resolve('ثاني', ctx);

      final r = resolver.resolve('دزله واتساب', ctx);
      expect(r.status, ContextResolutionStatus.messageDoctor);
      expect(r.intent, AssistantIntent.messageDoctor);
      expect(r.target?.doctorId, 'b');
      expect(ctx.pendingAction, 'whatsapp');
    });

    test('TEST 8 — لا، دزله واتساب keeps same doctor', () {
      final b = _doc(
        'b',
        'B',
        phone: '07701111111',
        whatsapp: '07702222222',
      );
      ctx.rememberResults([_doc('a', 'A'), b]);
      resolver.resolve('الثاني', ctx);
      final call = resolver.resolve('اتصل بيه', ctx);
      expect(call.pendingAction, 'call');
      expect(ctx.selectedEntity?.doctorId, 'b');

      final wa = resolver.resolve('لا، دزله واتساب', ctx);
      expect(wa.status, ContextResolutionStatus.messageDoctor);
      expect(wa.target?.doctorId, 'b');
      expect(ctx.selectedEntity?.doctorId, 'b');
      expect(ctx.pendingAction, 'whatsapp');
    });

    test('TEST 9 — ambiguous Ali then الثاني selects Ali B', () {
      final aliA = _doc('a', 'علي ناصر السعيدي', score: 82);
      final aliB = _doc('b', 'علي فليح جودة', score: 82);
      ctx.rememberResults([aliA, aliB], query: 'دكتور علي');
      expect(ctx.selectedEntity, isNull);
      expect(ctx.clarificationCandidates, hasLength(2));

      final r = resolver.resolve('الثاني', ctx);
      expect(r.target?.doctorId, 'b');
      expect(ctx.selectedEntity?.title, contains('فليح'));
    });

    test('TEST 10 — new confident doctor clears old selection', () {
      final old = _doc('old', 'قديم', score: 95, location: 'المنصور');
      ctx.rememberResults([old, _doc('x', 'آخر', score: 70)]);
      resolver.resolve('الأول', ctx);
      expect(ctx.selectedEntity?.doctorId, 'old');

      final naji = _doc(
        'naji',
        'ناجي عبد الله الركابي',
        score: 96,
        location: 'الحارثية',
      );
      ctx.rememberResults([naji], query: 'ناجي الركابي');
      expect(ctx.selectedEntity?.doctorId, 'naji');
      expect(ctx.selectedEntity?.doctorId, isNot('old'));
    });

    test('TEST 11 — typed and voice identical phrase', () {
      ctx.rememberResults([
        _doc('a', 'A'),
        _doc('b', 'B'),
        _doc('c', 'C'),
      ]);
      final typed = resolver.resolve('الثاني', ctx);
      final voiceCtx = ConversationContext();
      voiceCtx.rememberResults([
        _doc('a', 'A'),
        _doc('b', 'B'),
        _doc('c', 'C'),
      ]);
      final voice = resolver.resolve('الثاني', voiceCtx);
      expect(typed.status, voice.status);
      expect(typed.target?.doctorId, voice.target?.doctorId);
    });

    test('TEST 12 — location unavailable when empty', () {
      final b = _doc('b', 'B', location: null);
      ctx.rememberResults([_doc('a', 'A'), b]);
      resolver.resolve('الثاني', ctx);
      final r = resolver.resolve('وين عيادته؟', ctx);
      expect(r.status, ContextResolutionStatus.locationUnavailable);
      expect(r.message, isNot(contains('null')));
      expect(r.message.toLowerCase(), isNot(contains('invent')));
    });

    test('اختار الثاني / اريد الثاني / افتح الثاني', () {
      ctx.rememberResults([
        _doc('a', 'A'),
        _doc('b', 'B'),
        _doc('c', 'C'),
      ]);
      for (final q in ['اختار الثاني', 'اريد الثاني', 'افتح الثاني', 'الثاني منهم']) {
        ctx.selectEntity(null);
        final r = resolver.resolve(q, ctx);
        expect(r.target?.doctorId, 'b', reason: q);
      }
    });

    test('غير سياقي يمر للبحث العادي', () {
      ctx.rememberResults([_doc('a', 'A')]);
      final r = resolver.resolve('مختبر اليرموك', ctx);
      expect(r.status, ContextResolutionStatus.notContextual);
    });
  });

  group('ConversationContext authority', () {
    test('session-only reset clears all', () {
      ctx.rememberResults([_doc('a', 'A', score: 95)]);
      expect(ctx.hasSelection, isTrue);
      ctx.reset();
      expect(ctx.hasResults, isFalse);
      expect(ctx.hasSelection, isFalse);
      expect(ctx.pendingAction, isNull);
      expect(ctx.lastAssistantResponse, isNull);
    });

    test('typed ResultContext order drives ordinals (PC-0.2)', () {
      // نتائج مختلطة لا تبني ResultContext سلطوياً → لا ترتيبي من اللقطة القديمة.
      ctx.rememberResults([
        _doc('1', 'أول ظاهر'),
        SmartSearchResult(
          type: SmartSearchResultType.lab,
          title: 'مختبر',
          subtitle: '',
        ),
        _doc('2', 'ثاني طبيب'),
      ]);
      expect(ctx.currentResultContext, isNull);
      final mixed = const ContextResolver().resolve('الثاني', ctx);
      expect(mixed.target, isNull);

      // نتائج أطباء نقية فقط → الثاني من ResultContext.
      ctx.rememberResults([
        _doc('1', 'أول ظاهر'),
        _doc('2', 'ثاني طبيب'),
      ]);
      final r = const ContextResolver().resolve('الثاني', ctx);
      expect(r.target?.doctorId, '2');
    });
  });
}
