import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/search/voice_contact_command.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

void main() {
  group('اتصل دكتور ناجي — لا يبحث عن «اتصل ناجي»', () {
    test('prepareDoctorNameQuery يزيل فعل الاتصال', () {
      expect(
        ArabicTextUtils.prepareDoctorNameQuery('اتصل دكتور ناجي'),
        'ناجي',
      );
      expect(
        ArabicTextUtils.prepareDoctorNameQuery('أتصل دكتور ناجي'),
        'ناجي',
      );
      expect(
        ArabicTextUtils.prepareDoctorNameQuery('إتصل بالدكتور ناجي'),
        'ناجي',
      );
    });

    test('النية والبحث يستخدمان ناجي فقط', () async {
      for (final q in const [
        'اتصل دكتور ناجي',
        'أتصل دكتور ناجي',
        'إتصل بدكتور ناجي',
      ]) {
        final contact = VoiceContactCommand.tryParse(q);
        final intent = RuleBasedIntentResolver().resolve(q);
        expect(contact?.targetQuery, 'ناجي', reason: q);
        expect(intent.intent, AssistantIntent.callDoctor, reason: q);
        expect(intent.entities.doctorName, 'ناجي', reason: q);

        String? lookedUp;
        final plan = await SmartBrainPlanner(
          clinicalEnabled: false,
          doctorLookup: (name) async {
            lookedUp = name;
            return const <SmartSearchResult>[];
          },
        ).plan(query: q, context: ConversationContext());

        expect(lookedUp, 'ناجي', reason: q);
        expect(plan.message, isNot(contains('اتصل ناجي')), reason: q);
        expect(plan.message, contains('ناجي'), reason: q);
      }
    });
  });
}
