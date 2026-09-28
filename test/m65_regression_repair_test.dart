import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/models/lab_models.dart';
import 'package:ghadeer_clinic/search/arabic_text_utils.dart';
import 'package:ghadeer_clinic/search/smart_search_models.dart';
import 'package:ghadeer_clinic/search/voice_contact_command.dart';
import 'package:ghadeer_clinic/voice/conversation_context.dart';
import 'package:ghadeer_clinic/voice/intent/assistant_intent.dart';
import 'package:ghadeer_clinic/voice/intent/confidence_policy.dart';
import 'package:ghadeer_clinic/voice/intent/intent_resolver.dart';
import 'package:ghadeer_clinic/voice/intent/smart_brain_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

SmartSearchResult _doc(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.doctor,
      title: title,
      subtitle: 'أطفال',
      doctorId: id,
      score: 90,
      specialty: 'أطفال',
      phone: '07701111111',
      whatsapp: '07701111111',
    );

SmartSearchResult _lab(String id, String title) => SmartSearchResult(
      type: SmartSearchResultType.lab,
      title: title,
      subtitle: 'مختبر',
      labId: id,
      score: 90,
      phone: '07700000001',
      whatsapp: '07700000001',
      labName: title,
    );

/// M6.5 — إصلاحات انحدار جذرية (على→علي، تحليل بلا اسم، لقب+وحيد).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('M6.5 — على→علي لا يضاعف اسم الطبيب', () {
    test('VoiceContact + prepareQuery يبقيان علي ناصر مرة واحدة', () {
      const q = 'اتصل على دكتور علي ناصر السعيدي';
      final c = VoiceContactCommand.tryParse(q);
      expect(c?.targetQuery, 'علي ناصر السعيدي');
      expect(
        ArabicTextUtils.prepareDoctorNameQuery(c!.targetQuery),
        'علي ناصر السعيدي',
      );
      expect(
        ArabicTextUtils.prepareDoctorNameQuery(q),
        'علي ناصر السعيدي',
      );
      expect(
        ArabicTextUtils.prepareDoctorNameQuery('علي دكتور علي ناصر السعيدي'),
        'علي ناصر السعيدي',
      );
    });

    test('اتصل على الأول لا يُرسل اسماً زائفاً للمطابق', () {
      expect(
        ArabicTextUtils.prepareDoctorNameQuery('اتصل على الأول'),
        isEmpty,
      );
      final c = VoiceContactCommand.tryParse('اتصل على الأول');
      expect(c?.targetQuery, isEmpty);
    });
  });

  group('M6.5 — تحليل بلا اسم ≠ بحث طبيب', () {
    final resolver = RuleBasedIntentResolver();

    test('تحليل / أريد تحليل → findAnalysis بلا doctorName', () {
      for (final q in ['تحليل', 'أريد تحليل', 'اريد تحليل']) {
        final i = resolver.resolve(q);
        expect(i.intent, AssistantIntent.findAnalysis, reason: q);
        expect(i.entities.doctorName, isNull, reason: q);
        expect(i.entities.analysis, isNull, reason: q);
      }
    });

    test('مختبر تحاليل يبقى findLab لا findAnalysis', () {
      for (final q in ['أريد مختبر تحاليل', 'وين اكو مختبر تحاليل']) {
        final i = resolver.resolve(q);
        expect(i.intent, AssistantIntent.findLab, reason: q);
      }
    });

    test('C.B.C أثناء توضيح تحليل → اختيار CBC', () async {
      final ctx = ConversationContext();
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        analysisLookup: (_) async => [
          const AnalysisItem(
            id: 'cbc',
            name: 'CBC',
            shortName: 'CBC',
            nameAr: 'صورة الدم الكاملة',
            aliases: ['Complete Blood Count', 'صورة الدم'],
            isActive: true,
          ),
          const AnalysisItem(
            id: 'vitd',
            name: 'Vitamin D',
            shortName: 'Vit D',
            nameAr: 'فيتامين د',
            aliases: ['Vit D'],
            isActive: true,
          ),
        ],
        doctorLookup: (_) async => const [],
      );
      await planner.plan(query: 'تحليل', context: ctx);
      ctx.rememberResults([
        SmartSearchResult(
          type: SmartSearchResultType.analysis,
          title: 'صورة الدم الكاملة',
          subtitle: 'CBC',
          analysisId: 'cbc',
        ),
        SmartSearchResult(
          type: SmartSearchResultType.analysis,
          title: 'فيتامين د',
          subtitle: 'Vitamin D',
          analysisId: 'vitd',
        ),
      ]);
      expect(ctx.hasPendingClarification, isTrue);
      final plan = await planner.plan(query: 'C.B.C', context: ctx);
      expect(plan.kind, AssistantActionKind.selectEntity);
      expect(ctx.selectedAnalysis?.analysisId, 'cbc');
    });
  });

  group('M6.5 — لقب صريح + تطابق وحيد متوسط → تنفيذ', () {
    test('policy: لقب يرفع MEDIUM→HIGH؛ بلا لقب يبقى MEDIUM', () {
      expect(
        SmartBrainConfidencePolicy.forUniqueNameResolution(
          intentScore: 90,
          matchScore: 85,
          isUniqueNonAmbiguous: true,
          hasExplicitTypeHint: true,
        ),
        SmartBrainConfidenceBand.high,
      );
      expect(
        SmartBrainConfidencePolicy.forUniqueNameResolution(
          intentScore: 90,
          matchScore: 85,
          isUniqueNonAmbiguous: true,
          hasExplicitTypeHint: false,
        ),
        SmartBrainConfidenceBand.medium,
      );
    });

    test('واتساب لدكتور ناجي مع مختبر نشط → طبيب لا مختبر', () async {
      final home = _lab('home', 'مختبر سحب المنزل');
      final naji = _doc('naji', 'ناجي عبد الله الركابي');
      final ctx = ConversationContext();
      ctx.selectLaboratory(home);
      final planner = SmartBrainPlanner(
        clinicalEnabled: false,
        labLookup: (_) async => [home],
        doctorLookup: (q) async {
          final n = ArabicTextUtils.normalize(q);
          if (n.contains('ناجي')) return [naji];
          return const [];
        },
      );
      final plan = await planner.plan(
        query: 'أرسل رسالة واتساب لدكتور ناجي',
        context: ctx,
      );
      expect(plan.kind, AssistantActionKind.prepareWhatsApp);
      expect(plan.target?.doctorId, 'naji');
      expect(plan.target?.labId, isNull);
    });
  });

  group('M6.5 — نفي ورم الوجه مسار أسنان', () {
    test('زوجتي ماكو ورم بالوجه → رد غير فارغ', () async {
      final planner = SmartBrainPlanner(
        doctorLookup: (_) async => const [],
        labLookup: (_) async => [
          SmartSearchResult(
            type: SmartSearchResultType.lab,
            title: 'مختبر الغدير',
            subtitle: 'مختبر',
            labId: 'lab-ghadeer',
            score: 95,
          ),
        ],
        analysisLookup: (_) async => const [],
        packagesLookup: (_) async => const [],
        packagesForAnalysisLookup: (_) async => const [],
        activePackagesLookup: ({labId, nameQuery}) async => const [],
        discountedPackagesLookup: ({labId}) async => const [],
      );
      final ctx = ConversationContext();
      await planner.plan(query: 'زوجتي اللثة وارمة', context: ctx);
      await planner.plan(query: 'اني خايفة', context: ctx);
      final plan =
          await planner.plan(query: 'زوجتي ماكو ورم بالوجه', context: ctx);
      expect(plan.message.trim(), isNotEmpty);
      expect(plan.kind, isNot(AssistantActionKind.runDoctorSearch));
    });
  });
}
