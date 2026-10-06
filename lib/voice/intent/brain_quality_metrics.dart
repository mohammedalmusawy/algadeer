import 'package:shared_preferences/shared_preferences.dart';

/// عدادات غير حساسة لجودة العقل — بلا نص محادثة وبلا بيانات صحية.
class BrainQualityMetrics {
  BrainQualityMetrics._();

  static const _understandFailKey = 'brain_metric_understand_fail';
  static const _executeFailKey = 'brain_metric_execute_fail';
  static const _openSelectOkKey = 'brain_metric_open_select_ok';
  static const _liveRevalidateFailKey = 'brain_metric_live_revalidate_fail';
  static const _staleDataHintKey = 'brain_metric_stale_data_hint';

  static Future<void> recordUnderstandFail() => _inc(_understandFailKey);
  static Future<void> recordExecuteFail() => _inc(_executeFailKey);
  static Future<void> recordOpenSelectOk() => _inc(_openSelectOkKey);
  static Future<void> recordLiveRevalidateFail() =>
      _inc(_liveRevalidateFailKey);
  static Future<void> recordStaleDataHint() => _inc(_staleDataHintKey);

  static Future<Map<String, int>> snapshot() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'فشل فهم': prefs.getInt(_understandFailKey) ?? 0,
      'فشل تنفيذ': prefs.getInt(_executeFailKey) ?? 0,
      'فتح/اختيار ناجح': prefs.getInt(_openSelectOkKey) ?? 0,
      'فشل إعادة تحقق حية': prefs.getInt(_liveRevalidateFailKey) ?? 0,
      'تلميح بيانات قديمة': prefs.getInt(_staleDataHintKey) ?? 0,
    };
  }

  static Future<void> resetForTests() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_understandFailKey);
    await prefs.remove(_executeFailKey);
    await prefs.remove(_openSelectOkKey);
    await prefs.remove(_liveRevalidateFailKey);
    await prefs.remove(_staleDataHintKey);
  }

  static Future<void> _inc(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
    } catch (_) {}
  }
}
