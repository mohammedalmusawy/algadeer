import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../companion/personal_companion_profile_service.dart';
import '../utils/clinic_contact_message.dart';

/// قالب رسالة واتساب التلقائية — محلي على الجهاز (SharedPreferences).
///
/// لا مزامنة مع Supabase: كل جهاز يحتفظ بقالبه. غير المحفوظ = الافتراضي.
class WhatsAppMessageSettingsService {
  WhatsAppMessageSettingsService({this._prefs});

  SharedPreferences? _prefs;

  static const String storageKey = 'whatsapp_message_template';
  static const int maxLength = 600;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// القالب الفعّال: المحفوظ إن وُجد وغير فارغ، وإلا الافتراضي.
  Future<String> loadTemplate() async {
    try {
      final prefs = await _ensurePrefs();
      final saved = prefs.getString(storageKey);
      if (saved == null || saved.trim().isEmpty) {
        return ClinicContactMessage.defaultTemplate;
      }
      return saved;
    } catch (e) {
      debugPrint('WhatsAppMessageSettings: load failed $e');
      return ClinicContactMessage.defaultTemplate;
    }
  }

  Future<bool> hasCustomTemplate() async {
    final prefs = await _ensurePrefs();
    final saved = prefs.getString(storageKey);
    return saved != null && saved.trim().isNotEmpty;
  }

  /// يحفظ القالب. فارغ أو مطابق للافتراضي = إرجاع للافتراضي.
  /// يرجع false إن تجاوز [maxLength] (لا يُحفظ شيء).
  Future<bool> saveTemplate(String raw) async {
    final text = raw.replaceAll('\r\n', '\n').trim();
    if (text.length > maxLength) return false;
    if (text.isEmpty || text == ClinicContactMessage.defaultTemplate) {
      await resetTemplate();
      return true;
    }
    final prefs = await _ensurePrefs();
    await prefs.setString(storageKey, text);
    return true;
  }

  Future<void> resetTemplate() async {
    final prefs = await _ensurePrefs();
    await prefs.remove(storageKey);
  }

  /// نص الرسالة الجاهز للإرسال: القالب المحفوظ + الاسم من الـ onboarding.
  ///
  /// [providerIsDoctor]: true → «د. الاسم»، false → اسم المختبر/المركز كما هو.
  Future<String> buildPrefill({
    String? providerTitle,
    bool providerIsDoctor = true,
    PersonalCompanionProfileService? profileService,
  }) async {
    final template = await loadTemplate();
    String? name;
    try {
      name = await (profileService ?? PersonalCompanionProfileService())
          .preferredNameForPersonalization();
    } catch (_) {
      name = null;
    }
    return ClinicContactMessage.render(
      template: template,
      patientFullName: name,
      providerTitle: providerTitle,
      providerIsDoctor: providerIsDoctor,
    );
  }
}
