/// البحث المباشر باسم الطبيب — حرس تراجع.
///
/// كان «دق/دك» (أمر الاتصال العامي) يُقتطع كبادئة من «دكتور» فيصير الاسم
/// المستخرج «تور علي ناصر السعيدي» ويفشل المطابق. الإصلاح في
/// entity_extractor.dart و doctor_target_resolver.dart قصر الاقتطاع على
/// الكلمة الكاملة. هذا الاختبار يمنع عودة التسميم.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/doctor_name_matcher.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';

void main() {
  const matcher = DoctorNameMatcher();
  final resolver = RuleBasedIntentResolver();
  final planner = SmartBrainPlanner(intentResolver: resolver);

  const saeedi = 'الدكتور علي ناصر السعيدي';
  const other = 'ناجي عبد الله الركابي';

  const saeediQueries = [
    'دكتور علي ناصر السعيدي',
    'الدكتور علي ناصر السعيدي',
    'علي ناصر السعيدي',
    'د. علي ناصر السعيدي',
  ];

  test('direct doctor-name search: Ali Nasir variants + generic other', () async {
    for (final q in saeediQueries) {
      final intent = resolver.resolve(q);
      final name = intent.entities.doctorName;
      expect(name, isNotNull, reason: 'q=$q');
      expect(name!.contains('تور'), isFalse, reason: 'poisoned name for q=$q → $name');
      expect(
        matcher.score(doctorName: saeedi, query: name).score,
        greaterThanOrEqualTo(90),
        reason: 'q=$q name=$name',
      );
      expect(
        matcher.score(doctorName: 'الدكتور علي فليح جودة', query: name).score,
        lessThan(50),
        reason: 'must not match Fleih for q=$q',
      );

      final ctx = ConversationContext();
      final plan = await planner.plan(query: q, context: ctx);
      final doctorQuery = plan.doctorQuery ?? name;
      expect(doctorQuery.contains('تور'), isFalse, reason: 'plan q=$q');
      expect(
        matcher.score(doctorName: saeedi, query: doctorQuery).score,
        greaterThanOrEqualTo(90),
        reason: 'plan doctorQuery=$doctorQuery for q=$q',
      );
    }

    // طبيب آخر لإثبات العمومية
    const otherQ = 'دكتور ناجي عبد الله الركابي';
    final otherIntent = resolver.resolve(otherQ);
    final otherName = otherIntent.entities.doctorName;
    expect(otherName, isNotNull);
    expect(otherName!.contains('تور'), isFalse);
    expect(
      matcher.score(doctorName: other, query: otherName).score,
      greaterThanOrEqualTo(90),
    );
  });
}
