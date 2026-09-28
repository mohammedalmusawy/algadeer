import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/conversation/smart_brain_suggested_actions.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';

SmartSearchResult _doctor({
  String? phone,
  String? whatsapp,
  String? clinicLocation,
}) {
  return SmartSearchResult(
    type: SmartSearchResultType.doctor,
    title: 'د. ناجي',
    subtitle: 'عظام',
    doctorId: 'naji',
    phone: phone,
    whatsapp: whatsapp,
    clinicLocation: clinicLocation,
    specialty: 'عظام',
  );
}

void main() {
  group('SmartBrainSuggestedActionsBuilder', () {
    test('بدون رقم — لا يظهر اتصال ولا واتساب', () {
      final actions = SmartBrainSuggestedActionsBuilder.forResults([
        _doctor(),
      ]);
      final kinds = actions.map((a) => a.kind).toSet();
      expect(kinds.contains(SmartBrainSuggestedActionKind.openDetails), isTrue);
      expect(kinds.contains(SmartBrainSuggestedActionKind.call), isFalse);
      expect(kinds.contains(SmartBrainSuggestedActionKind.whatsapp), isFalse);
    });

    test('مع هاتف فقط — اتصال بلا واتساب (phone ≠ WhatsApp)', () {
      final actions = SmartBrainSuggestedActionsBuilder.forResults([
        _doctor(phone: '07701234567'),
      ]);
      final kinds = actions.map((a) => a.kind).toSet();
      expect(kinds.contains(SmartBrainSuggestedActionKind.call), isTrue);
      expect(kinds.contains(SmartBrainSuggestedActionKind.whatsapp), isFalse);
    });

    test('موقع حقيقي فقط يظهر زر الموقع', () {
      final without = SmartBrainSuggestedActionsBuilder.forResults([
        _doctor(phone: '0770'),
      ]);
      expect(
        without.any((a) => a.kind == SmartBrainSuggestedActionKind.showLocation),
        isFalse,
      );

      final withLoc = SmartBrainSuggestedActionsBuilder.forResults([
        _doctor(phone: '0770', clinicLocation: 'الكرادة'),
      ]);
      expect(
        withLoc.any((a) => a.kind == SmartBrainSuggestedActionKind.showLocation),
        isTrue,
      );
    });

    test('مختبر → اقتراح باقات ضمن الحد الأقصى', () {
      final lab = SmartSearchResult(
        type: SmartSearchResultType.lab,
        title: 'مختبر الحياة',
        subtitle: 'مختبر',
        labId: 'lab1',
        phone: '0770',
      );
      final actions = SmartBrainSuggestedActionsBuilder.forResults(
        [lab],
        maxActions: 4,
      );
      expect(actions.length, lessThanOrEqualTo(4));
      expect(
        actions.any((a) => a.kind == SmartBrainSuggestedActionKind.showPackages),
        isTrue,
      );
    });

    test('نتائج متعددة → المزيد إن بقي مكان', () {
      final actions = SmartBrainSuggestedActionsBuilder.forResults(
        [
          _doctor(phone: '0770'),
          _doctor(phone: '0771'),
        ],
        maxActions: 5,
      );
      expect(
        actions.any(
          (a) => a.kind == SmartBrainSuggestedActionKind.showMoreResults,
        ),
        isTrue,
      );
    });
  });
}
