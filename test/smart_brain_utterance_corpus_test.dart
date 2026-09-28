import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/specialty_catalog.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/voice_specialty_search_command.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/ghadeer_scope_gate.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';

/// مرحلة A — corpus قابل للتوسع + aliases عراقية (جهال/اطفل).
void main() {
  final fixtureFile = File('test/fixtures/smart_brain_utterance_corpus.json');

  late List<Map<String, dynamic>> rows;

  setUpAll(() {
    expect(fixtureFile.existsSync(), isTrue, reason: fixtureFile.path);
    final decoded = jsonDecode(fixtureFile.readAsStringSync()) as List<dynamic>;
    rows = decoded.cast<Map<String, dynamic>>();
    expect(rows.length, greaterThanOrEqualTo(10));
  });

  group('Iraqi aliases — أطفال / جهال', () {
    test('searchMeaning يوحّد جهال و اطفل إلى اطفال', () {
      expect(
        ArabicTextUtils.toSearchMeaning('طبيب جهال'),
        contains('اطفال'),
      );
      expect(
        ArabicTextUtils.toSearchMeaning('دكتور اطفل'),
        contains('اطفال'),
      );
    });

    test('SpecialtyCatalog يطابق جهال و اطفل', () {
      expect(SpecialtyCatalog.matchPhrase('جهال')?.id, 'pediatrics');
      expect(SpecialtyCatalog.matchPhrase('اطفل')?.id, 'pediatrics');
      expect(SpecialtyCatalog.matchPhrase('اطفال')?.id, 'pediatrics');
    });

    test('VoiceSpecialtySearchCommand يلتقط طبيب جهال', () {
      final cmd = VoiceSpecialtySearchCommand.tryParse('اريد طبيب جهال');
      expect(cmd, isNotNull);
      expect(cmd!.resolvedSpecialtyName, contains('أطفال'));
    });
  });

  group('utterance corpus table', () {
    test('كل صف يطابق expect', () {
      final resolver = RuleBasedIntentResolver();
      for (final row in rows) {
        final id = row['id'] as String;
        final q = row['query'] as String;
        final expectKind = row['expect'] as String;

        switch (expectKind) {
          case 'specialty':
            final cmd = VoiceSpecialtySearchCommand.tryParse(q);
            final matched = SpecialtyCatalog.matchPhrase(
              ArabicTextUtils.toSearchMeaning(q),
            );
            expect(
              cmd != null || matched?.id == 'pediatrics',
              isTrue,
              reason: '$id · $q',
            );
            break;
          case 'platform':
            final intent = resolver.resolve(q);
            expect(
              GhadeerScopeGate.isPlatformOwnedIntent(intent.intent) ||
                  GhadeerScopeGate.hasPlatformCue(q) ||
                  !GhadeerScopeGate.isOutOfScope(q),
              isTrue,
              reason: '$id · $q · ${intent.intent}',
            );
            expect(
              GhadeerScopeGate.shouldRefuse(query: q, intent: intent),
              isFalse,
              reason: '$id · must not refuse platform',
            );
            break;
          case 'out_of_scope':
            final intent = resolver.resolve(q);
            expect(
              GhadeerScopeGate.shouldRefuse(query: q, intent: intent) ||
                  GhadeerScopeGate.isOutOfScope(q),
              isTrue,
              reason: '$id · $q · ${intent.intent}',
            );
            break;
          case 'search_meaning_atfal':
            expect(
              ArabicTextUtils.toSearchMeaning(q),
              contains('اطفال'),
              reason: id,
            );
            break;
          case 'search_meaning_whatsapp':
            expect(
              ArabicTextUtils.toSearchMeaning(q),
              contains('واتساب'),
              reason: id,
            );
            break;
          default:
            fail('unknown expect=$expectKind for $id');
        }
      }
    });

    test('نية اتصال/واتساب تبقى منصة', () {
      final resolver = RuleBasedIntentResolver();
      final call = resolver.resolve('اتصل بالدكتور ناجي');
      expect(
        call.intent == AssistantIntent.callDoctor ||
            GhadeerScopeGate.isPlatformOwnedIntent(call.intent),
        isTrue,
      );
    });
  });
}
