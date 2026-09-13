import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/search/smart_navigation.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';

void main() {
  group('SmartNavigationResolver', () {
    final resolver = SmartNavigationResolver();

    test('opens single confident doctor directly', () {
      final decision = resolver.resolve(
        query: 'افتح الدكتور علي ناصر السعيدي',
        results: const [
          SmartSearchResult(
            type: SmartSearchResultType.doctor,
            title: 'علي ناصر السعيدي',
            subtitle: 'باطنية',
            doctorId: 'd1',
            score: 95,
          ),
        ],
      );

      expect(decision.shouldNavigateDirectly, isTrue);
      expect(decision.action, SmartNavAction.openDoctor);
      expect(decision.target?.doctorId, 'd1');
    });

    test('does not pick randomly when multiple doctors match', () {
      final decision = resolver.resolve(
        query: 'الدكتور علي',
        results: const [
          SmartSearchResult(
            type: SmartSearchResultType.doctor,
            title: 'علي أحمد',
            subtitle: 'باطنية',
            doctorId: 'd1',
            score: 90,
          ),
          SmartSearchResult(
            type: SmartSearchResultType.doctor,
            title: 'علي حسين',
            subtitle: 'أطفال',
            doctorId: 'd2',
            score: 88,
          ),
        ],
      );

      expect(decision.shouldNavigateDirectly, isFalse);
      expect(decision.ambiguous, isTrue);
      expect(decision.message, contains('أكثر من طبيب'));
    });

    test('opens only the doctor matching all name tokens', () {
      final decision = resolver.resolve(
        query: 'علي ناصر',
        results: const [
          SmartSearchResult(
            type: SmartSearchResultType.doctor,
            title: 'الدكتور علي ناصر السعيدي',
            subtitle: 'باطنية',
            doctorId: 'd-saeedi',
            score: 90,
          ),
          SmartSearchResult(
            type: SmartSearchResultType.doctor,
            title: 'الدكتور علي فليح جودة',
            subtitle: 'جراحة',
            doctorId: 'd-fleih',
            score: 90,
          ),
        ],
      );

      expect(decision.shouldNavigateDirectly, isTrue);
      expect(decision.action, SmartNavAction.openDoctor);
      expect(decision.target?.doctorId, 'd-saeedi');
    });

    test('full doctor title opens only the matching doctor', () {
      final decision = resolver.resolve(
        query: 'الدكتور علي ناصر السعيدي',
        results: const [
          SmartSearchResult(
            type: SmartSearchResultType.doctor,
            title: 'الدكتور علي ناصر السعيدي',
            subtitle: 'باطنية',
            doctorId: 'd-saeedi',
            score: 100,
          ),
          SmartSearchResult(
            type: SmartSearchResultType.doctor,
            title: 'الدكتور علي فليح جودة',
            subtitle: 'جراحة',
            doctorId: 'd-fleih',
            score: 85,
          ),
        ],
      );

      expect(decision.shouldNavigateDirectly, isTrue);
      expect(decision.target?.doctorId, 'd-saeedi');
    });

    test('opens single lab directly', () {
      final decision = resolver.resolve(
        query: 'مختبر النور',
        results: const [
          SmartSearchResult(
            type: SmartSearchResultType.lab,
            title: 'مختبر النور',
            subtitle: 'بغداد',
            labId: 'l1',
            score: 100,
          ),
        ],
      );

      expect(decision.shouldNavigateDirectly, isTrue);
      expect(decision.action, SmartNavAction.openLab);
    });

    test('opens single offer/package directly', () {
      final decision = resolver.resolve(
        query: 'باقة الفحص الشامل',
        results: const [
          SmartSearchResult(
            type: SmartSearchResultType.offer,
            title: 'باقة الفحص الشامل',
            subtitle: 'عرض — مختبر النور',
            labId: 'l1',
            packageId: 'p1',
            score: 100,
            oldPrice: 25000,
            newPrice: 18000,
            discountPercent: 28,
          ),
        ],
      );

      expect(decision.shouldNavigateDirectly, isTrue);
      expect(decision.action, SmartNavAction.openOffer);
    });

    test('analysis shows related packages without random open', () {
      final decision = resolver.resolve(
        query: 'تحليل ALT',
        results: const [
          SmartSearchResult(
            type: SmartSearchResultType.analysis,
            title: 'ALT',
            subtitle: 'Alanine Aminotransferase',
            analysisId: 'a1',
            score: 100,
          ),
          SmartSearchResult(
            type: SmartSearchResultType.package,
            title: 'باقة الكبد',
            subtitle: 'تحتوي ALT',
            labId: 'l1',
            packageId: 'p1',
            score: 90,
            relatedAnalysisId: 'a1',
            relatedAnalysisTitle: 'ALT',
          ),
          SmartSearchResult(
            type: SmartSearchResultType.offer,
            title: 'باقة كبد مخفضة',
            subtitle: 'تحتوي ALT',
            labId: 'l2',
            packageId: 'p2',
            score: 88,
            relatedAnalysisId: 'a1',
            relatedAnalysisTitle: 'ALT',
          ),
        ],
      );

      expect(decision.action, SmartNavAction.showAnalysisPackages);
      expect(decision.shouldNavigateDirectly, isFalse);
      expect(decision.ambiguous, isTrue);
    });
  });

  group('AssistantStructuredIntent', () {
    test('parses structured offer search payload', () {
      final intent = AssistantStructuredIntent.fromJson({
        'intent': 'offer_search',
        'entity_type': 'offer',
        'search_terms': ['تحاليل كبد'],
        'filters': {'active_only': true},
        'navigation': {'direct_if_single_confident_match': true},
        'urgency': 'low',
      });

      expect(intent.intent, 'offer_search');
      expect(intent.entityType, 'offer');
      expect(intent.searchTerms, ['تحاليل كبد']);
      expect(intent.filters['active_only'], isTrue);
      expect(intent.directIfSingleConfidentMatch, isTrue);
      expect(intent.isUrgent, isFalse);
    });
  });
}
