import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'follow_up_insights.dart';
import 'patient_health_models.dart';

/// المدى الذي كتبه المريض من طبيبه، محفوظ على الجهاز فقط (لكل مرض).
/// لا يُرسل لأي خادم، ولا يضع التطبيق أي مدى افتراضي.
class FollowUpTargetStore {
  const FollowUpTargetStore();

  static String keyFor(String userId, String conditionId) =>
      'follow_up_target_v1_${userId}_$conditionId';

  Future<FollowUpTarget> load(String userId, String conditionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyFor(userId, conditionId));
      if (raw == null || raw.isEmpty) return const FollowUpTarget();
      final map = jsonDecode(raw);
      if (map is! Map) return const FollowUpTarget();
      double? read(String k) {
        final v = map[k];
        return v is num ? v.toDouble() : null;
      }

      return FollowUpTarget(
        low: read('low'),
        high: read('high'),
        secondLow: read('secondLow'),
        secondHigh: read('secondHigh'),
        unit: map['unit'] is String ? unitFromDb(map['unit'] as String) : null,
      );
    } catch (e, st) {
      debugPrint('FollowUpTargetStore.load failed: $e\n$st');
      return const FollowUpTarget();
    }
  }

  Future<void> save(
    String userId,
    String conditionId,
    FollowUpTarget target,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = keyFor(userId, conditionId);
    if (target.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(
      key,
      jsonEncode({
        'low': ?target.low,
        'high': ?target.high,
        'secondLow': ?target.secondLow,
        'secondHigh': ?target.secondHigh,
        if (target.unit != null) 'unit': unitToDb(target.unit!),
      }),
    );
  }
}

/// يتحقق من مدى يكتبه المريض: أرقام موجبة والحد الأدنى أقل من الأعلى.
String? validateFollowUpTarget(FollowUpTarget target) {
  bool bad(double? lo, double? hi) =>
      (lo != null && lo <= 0) ||
      (hi != null && hi <= 0) ||
      (lo != null && hi != null && lo >= hi);
  if (bad(target.low, target.high) ||
      bad(target.secondLow, target.secondHigh)) {
    return 'الحد الأدنى لازم يكون أقل من الأعلى، والأرقام أكبر من صفر.';
  }
  return null;
}
