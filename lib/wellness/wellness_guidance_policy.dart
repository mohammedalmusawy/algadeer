import '../health/preventive/preventive_guidance_catalog_source.dart';
import '../health/preventive/preventive_guidance_context.dart';
import '../health/preventive/preventive_guidance_models.dart';
import '../health/preventive/preventive_guidance_planner.dart';
import '../health/preventive/preventive_guidance_response_builder.dart';
import 'wellness_command_interpreter.dart';
import 'wellness_models.dart';

/// سياسة توجيه العافية — تعيد استخدام أدلة PC-1.7 بلا تكرار أرقام.
class WellnessGuidancePolicy {
  WellnessGuidancePolicy({
    PreventiveGuidanceCatalogSource? catalog,
    PreventiveGuidancePlanner? planner,
    PreventiveGuidanceResponseBuilder? responses,
  })  : _catalog = catalog ?? LocalPreventiveGuidanceCatalog(),
        _planner = planner ?? PreventiveGuidancePlanner(catalog: catalog),
        _responses =
            responses ?? PreventiveGuidanceResponseBuilder(catalog: catalog);

  final PreventiveGuidanceCatalogSource _catalog;
  final PreventiveGuidancePlanner _planner;
  final PreventiveGuidanceResponseBuilder _responses;

  /// معرّفات فقط — العتبات الرقمية تبقى في PreventiveGuidanceResponseBuilder.
  static const evidenceRuleIds = [
    'prev_activity_adult_general',
    'prev_walking_practical_example',
  ];

  Future<({String message, bool usedPreventive})> buildEvidenceAwareAdvice({
    required WellnessCommandInterpretation interp,
    required PreventiveGuidanceContext baseContext,
  }) async {
    final topic = switch (interp.topic) {
      WellnessTopic.walking => PreventiveGuidanceTopic.walking,
      WellnessTopic.sedentaryTime => PreventiveGuidanceTopic.employeeRoutine,
      WellnessTopic.exercise ||
      WellnessTopic.generalMovement =>
        PreventiveGuidanceTopic.activity,
      _ => PreventiveGuidanceTopic.walking,
    };

    final ctx = PreventiveGuidanceContext(
      computedAge: baseContext.computedAge,
      sexSelection: baseContext.sexSelection,
      userContext: baseContext.userContext,
      permittedConditionKeys: baseContext.permittedConditionKeys,
      emotionalCategory: baseContext.emotionalCategory,
      emotionalOverload: baseContext.emotionalOverload,
      requestTopic: topic,
      intent: interp.asksPublicHealthTargets
          ? PreventiveIntent.walkingAdvice
          : PreventiveIntent.requestedAdvice,
      catalogAvailable: baseContext.catalogAvailable,
    );

    final plan = await _planner.plan(context: ctx);
    if (plan.selectedRuleIds.isEmpty) {
      return (message: '', usedPreventive: false);
    }
    final message = await _responses.build(plan: plan, context: ctx);
    return (message: message, usedPreventive: true);
  }

  PreventiveGuidanceCatalogSource get catalog => _catalog;
}
