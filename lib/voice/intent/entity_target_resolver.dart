import 'analysis_target_resolver.dart';
import 'assistant_intent.dart';
import 'doctor_target_resolver.dart';
import 'intent_result.dart';
import 'laboratory_target_resolver.dart';
import 'package_target_resolver.dart';
import '../conversation_context.dart';

/// منسّق خفيف يوجّه حسب نوع الكيان.
class EntityTargetResolver {
  const EntityTargetResolver({
    DoctorTargetResolver? doctorResolver,
    LaboratoryTargetResolver? laboratoryResolver,
    AnalysisTargetResolver? analysisResolver,
    PackageTargetResolver? packageResolver,
  })  : _doctors = doctorResolver ?? const DoctorTargetResolver(),
        _labs = laboratoryResolver ?? const LaboratoryTargetResolver(),
        _analyses = analysisResolver ?? const AnalysisTargetResolver(),
        _packages = packageResolver ?? const PackageTargetResolver();

  final DoctorTargetResolver _doctors;
  final LaboratoryTargetResolver _labs;
  final AnalysisTargetResolver _analyses;
  final PackageTargetResolver _packages;

  DoctorTargetResolver get doctors => _doctors;
  LaboratoryTargetResolver get laboratories => _labs;
  AnalysisTargetResolver get analyses => _analyses;
  PackageTargetResolver get packages => _packages;

  static bool prefersPackage({
    required IntentResult intent,
    required ConversationContext context,
  }) {
    // Step 9: الترتيب دائماً عبر _planSelect + currentResultContext.
    if (intent.intent == AssistantIntent.selectResult) {
      return false;
    }

    final hint = intent.entities.actionHint;
    if (hint == 'package_price' ||
        hint == 'package_analyses' ||
        hint == 'package_lab' ||
        hint == 'offers' ||
        hint == 'cheapest' ||
        hint == 'compare_packages' ||
        hint == 'best_unsupported' ||
        hint == 'filter_analyses') {
      return true;
    }
    if ((intent.entities.packageName ?? '').trim().isNotEmpty) return true;
    if (intent.entities.analysisTerms.length >= 2 &&
        (intent.intent == AssistantIntent.findPackage ||
            intent.intent == AssistantIntent.findOffer)) {
      return true;
    }
    if (intent.intent == AssistantIntent.findOffer) return true;
    if (intent.intent == AssistantIntent.findPackage) {
      // كتالوج باقات المختبر النشط يبقى لمسار المختبر (Step 6).
      final labScopedCatalogue =
          ((intent.entities.packageName ?? '').trim().isEmpty) &&
              intent.entities.analysisTerms.isEmpty &&
              hint != 'offers' &&
              hint != 'cheapest' &&
              hint != 'filter_analyses' &&
              (context.activeEntityType == ConversationEntityType.laboratory ||
                  (intent.entities.laboratory ?? '').trim().isNotEmpty);
      if (labScopedCatalogue) return false;
      // قائمة عامة / اسم باقة / فلاتر → مسار الباقة.
      return true;
    }
    if (context.activeEntityType == ConversationEntityType.package) {
      switch (intent.intent) {
        case AssistantIntent.findPackage:
        case AssistantIntent.findOffer:
        case AssistantIntent.findAnalysis:
        case AssistantIntent.callDoctor:
        case AssistantIntent.messageDoctor:
        case AssistantIntent.callLab:
        case AssistantIntent.messageLab:
        case AssistantIntent.showLocation:
        case AssistantIntent.showProfile:
          return true;
        case AssistantIntent.findLab:
          // بحث مختبر صريح يبدّل الكيان — لا تسرق مسار الباقة.
          return (intent.entities.laboratory ?? '').trim().isEmpty;
        default:
          break;
      }
    }
    return false;
  }

  static bool prefersAnalysis({
    required IntentResult intent,
    required ConversationContext context,
  }) {
    if (prefersPackage(intent: intent, context: context)) return false;

    // Step 9: ordinal → _planSelect فقط.
    if (intent.intent == AssistantIntent.selectResult) {
      return false;
    }

    final hint = intent.entities.actionHint;
    if (hint == 'packages_for_analysis' ||
        hint == 'labs_for_analysis' ||
        hint == 'where_analysis' ||
        hint == 'search') {
      if (intent.intent == AssistantIntent.findAnalysis) return true;
    }
    if ((intent.entities.analysis ?? '').trim().isNotEmpty &&
        intent.intent != AssistantIntent.findPackage) {
      return true;
    }
    if (intent.intent == AssistantIntent.findAnalysis &&
        hint != 'lab_catalogue') {
      return true;
    }
    if (context.activeEntityType == ConversationEntityType.analysis) {
      switch (intent.intent) {
        case AssistantIntent.findAnalysis:
        case AssistantIntent.findPackage:
        case AssistantIntent.callDoctor:
        case AssistantIntent.messageDoctor:
        case AssistantIntent.showLocation:
        case AssistantIntent.showProfile:
          return true;
        case AssistantIntent.findLab:
          return (intent.entities.laboratory ?? '').trim().isEmpty;
        default:
          break;
      }
    }
    return false;
  }

  /// هل النية/السياق يميلان للمختبر؟
  static bool prefersLaboratory({
    required IntentResult intent,
    required ConversationContext context,
  }) {
    if (prefersPackage(intent: intent, context: context)) return false;
    if (prefersAnalysis(intent: intent, context: context)) return false;

    if (intent.intent == AssistantIntent.selectResult) {
      return false;
    }

    switch (intent.intent) {
      case AssistantIntent.findLab:
      case AssistantIntent.callLab:
      case AssistantIntent.messageLab:
        return true;
      case AssistantIntent.findPackage:
        // باقات المختبر المحدد فقط.
        return true;
      case AssistantIntent.findAnalysis:
        return intent.entities.actionHint == 'lab_catalogue' ||
            ((intent.entities.analysis ?? '').trim().isEmpty &&
                context.activeEntityType == ConversationEntityType.laboratory);
      default:
        break;
    }
    if ((intent.entities.laboratory ?? '').trim().isNotEmpty) return true;
    if (context.activeEntityType == ConversationEntityType.laboratory) {
      switch (intent.intent) {
        case AssistantIntent.callDoctor:
        case AssistantIntent.messageDoctor:
        case AssistantIntent.showLocation:
        case AssistantIntent.showProfile:
          return true;
        default:
          break;
      }
    }
    return false;
  }
}
