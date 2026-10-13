import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../doctors/doctor_card_links.dart';
import '../services/admin_password_change_page.dart';
import '../services/favorites_cloud.dart';

enum PatientAuthStatus { signedIn, confirmationPending, resetRequested, failed }

class PatientAuthResult {
  const PatientAuthResult(this.status, this.message);

  final PatientAuthStatus status;
  final String message;
}

const patientConfirmationPendingMessage =
    'طُلب إرسال رسالة تأكيد إلى بريدك. لم نتحقق من وصولها. '
    'إن وصلتك، افتح الرابط ثم ارجع وسجّل الدخول.';

const patientResetRequestedMessage =
    'طُلب إرسال رابط استعادة كلمة المرور إلى بريدك. '
    'لم نتحقق من وصول الرسالة إلى صندوق الوارد.';

const patientAdminEmailRejectedMessage =
    'هذا البريد لحساب الإدارة. الملف الصحي يحتاج بريداً آخر، '
    'وحساب المريض ما يفتح إدارة الأطباء أو المختبرات أو الصيدليات.';

abstract class PatientAuthApi {
  Future<PatientAuthResult> signIn({
    required String email,
    required String password,
  });

  Future<PatientAuthResult> signUp({
    required String email,
    required String password,
  });

  Future<PatientAuthResult> requestPasswordReset({required String email});

  Future<PatientAuthResult> updatePassword({required String password});

  Future<void> signOut();

  Future<void> deleteAccount();
}

bool isClinicAdminEmail(String? email) {
  return (email ?? '').trim().toLowerCase() == kAdminEmail.toLowerCase();
}

String? patientAccountDeletionBlockedReason(String? email) {
  if (isClinicAdminEmail(email)) return patientAdminEmailRejectedMessage;
  return null;
}

String? validatePatientCredentials(String email, String password) {
  final trimmed = email.trim();
  if (isClinicAdminEmail(trimmed)) return patientAdminEmailRejectedMessage;
  if (!trimmed.contains('@') || !trimmed.contains('.')) {
    return 'اكتب بريداً إلكترونياً صحيحاً.';
  }
  if (password.length < 8) return 'كلمة المرور لازم تكون 8 أحرف على الأقل.';
  return null;
}

String arabicAuthFailure(String raw, {String? code, String? status}) {
  final lower = raw.toLowerCase();
  final codeLower = (code ?? '').toLowerCase();
  final statusCode = (status ?? '').trim();
  if (lower.contains('email not confirmed') ||
      lower.contains('not confirmed') ||
      codeLower == 'email_not_confirmed') {
    return 'البريد غير مؤكد بعد. افتح رسالة التأكيد إن وصلت، ثم سجّل الدخول. '
        'ما نتحقق من صندوق الوارد من داخل التطبيق.';
  }
  if (lower.contains('invalid login') || lower.contains('invalid credentials')) {
    return 'البريد أو كلمة المرور غير صحيحة.';
  }
  // وثائق Supabase Auth: مزوّد البريد المدمج ≈ 2 رسالة/ساعة لكل مشروع.
  // الرسالة العربية هنا تطابق استجابة over_email_send_rate_limit / 429.
  if (statusCode == '429' ||
      codeLower.contains('rate_limit') ||
      codeLower == 'over_email_send_rate_limit' ||
      (lower.contains('rate') && lower.contains('limit'))) {
    return 'تعذر إرسال الرسالة الآن. حاول بعد قليل.';
  }
  if (lower.contains('user already registered') ||
      lower.contains('already been registered') ||
      codeLower == 'user_already_exists') {
    return 'هذا البريد مسجّل. جرّب الدخول أو استعادة كلمة المرور.';
  }
  return 'تعذر الطلب: $raw';
}

const patientAuthReturnPath = '/patient-health';

bool isPatientHealthReturnUri(Uri uri) {
  final frag = uri.fragment.split('?').first;
  if (frag == patientAuthReturnPath ||
      frag == 'patient-health' ||
      frag.startsWith('/patient-health')) {
    return true;
  }
  if (uri.host == 'patient-health') return true;
  return uri.pathSegments.contains('patient-health');
}

String _originForAuthRedirect({required bool web, String? origin}) {
  if (web) {
    final raw = (origin ?? Uri.base.origin).trim();
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }
  return DoctorCardLinks.publicWebBase;
}

/// رابط الرجوع بعد تأكيد البريد أو الاستعادة. لازم يُضاف في Redirect URLs.
String patientAuthRedirectTo({bool web = kIsWeb, String? origin}) {
  return '${_originForAuthRedirect(web: web, origin: origin)}/#$patientAuthReturnPath';
}

String? patientPasswordResetRedirectTo({bool web = kIsWeb, String? origin}) {
  return patientAuthRedirectTo(web: web, origin: origin);
}

Future<void> completePatientAccountDeletion({
  required Future<Object?> Function() invoke,
  required Future<void> Function() signOut,
  int attempts = 3,
}) async {
  Object? lastError;
  for (var attempt = 0; attempt < attempts; attempt++) {
    try {
      final data = await invoke();
      if (data is Map && data['ok'] == true) {
        await signOut();
        return;
      }
      final code = data is Map ? data['code']?.toString() : null;
      final message = data is Map
          ? (data['error']?.toString() ?? 'تعذر حذف الحساب.')
          : 'تعذر حذف الحساب.';
      lastError = StateError(message);
      if (code == 'admin_forbidden' || code == 'not_authenticated') {
        throw lastError;
      }
    } catch (error) {
      lastError = error;
      if (error is StateError &&
          (error.message.contains('حساب الإدارة') ||
              error.message.contains('سجّل الدخول'))) {
        rethrow;
      }
    }
  }
  throw lastError ?? StateError('تعذر حذف الحساب. حاول مرة أخرى.');
}

class SupabasePatientAuthApi implements PatientAuthApi {
  SupabasePatientAuthApi(this._client);

  final SupabaseClient _client;

  @override
  Future<PatientAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final local = validatePatientCredentials(email, password);
    if (local != null) return PatientAuthResult(PatientAuthStatus.failed, local);
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.session == null || isClinicAdminEmail(response.user?.email)) {
        await _client.auth.signOut();
        return const PatientAuthResult(
          PatientAuthStatus.failed,
          patientAdminEmailRejectedMessage,
        );
      }
      // المفضلة المحفوظة بالحساب ترجع وتندمج ويا اللي على الجهاز.
      await FavoritesCloud.instance.syncAll();
      return const PatientAuthResult(PatientAuthStatus.signedIn, 'تم الدخول.');
    } on AuthException catch (error) {
      return PatientAuthResult(
        PatientAuthStatus.failed,
        arabicAuthFailure(
          error.message,
          code: error.code,
          status: error.statusCode,
        ),
      );
    }
  }

  @override
  Future<PatientAuthResult> signUp({
    required String email,
    required String password,
  }) async {
    final local = validatePatientCredentials(email, password);
    if (local != null) return PatientAuthResult(PatientAuthStatus.failed, local);
    try {
      final redirect = patientAuthRedirectTo();
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: redirect,
      );
      // لا نسجّل بريداً ولا كلمة مرور — فقط حالة الاستجابة للتشخيص المحلي.
      debugPrint(
        '[patient_auth.signUp] session=${response.session != null} '
        'user=${response.user != null} redirectHost='
        '${Uri.tryParse(redirect)?.host ?? '?'}',
      );
      if (response.session == null) {
        return const PatientAuthResult(
          PatientAuthStatus.confirmationPending,
          patientConfirmationPendingMessage,
        );
      }
      if (isClinicAdminEmail(response.user?.email)) {
        await _client.auth.signOut();
        return const PatientAuthResult(
          PatientAuthStatus.failed,
          patientAdminEmailRejectedMessage,
        );
      }
      return const PatientAuthResult(PatientAuthStatus.signedIn, 'تم إنشاء الحساب.');
    } on AuthException catch (error) {
      debugPrint(
        '[patient_auth.signUp] AuthException status=${error.statusCode} '
        'code=${error.code}',
      );
      return PatientAuthResult(
        PatientAuthStatus.failed,
        arabicAuthFailure(error.message, code: error.code, status: error.statusCode),
      );
    }
  }

  @override
  Future<PatientAuthResult> requestPasswordReset({required String email}) async {
    final trimmed = email.trim();
    if (isClinicAdminEmail(trimmed)) {
      return const PatientAuthResult(
        PatientAuthStatus.failed,
        patientAdminEmailRejectedMessage,
      );
    }
    if (!trimmed.contains('@')) {
      return const PatientAuthResult(
        PatientAuthStatus.failed,
        'اكتب البريد الإلكتروني.',
      );
    }
    try {
      await _client.auth.resetPasswordForEmail(
        trimmed,
        redirectTo: patientPasswordResetRedirectTo(),
      );
      return const PatientAuthResult(
        PatientAuthStatus.resetRequested,
        patientResetRequestedMessage,
      );
    } on AuthException catch (error) {
      debugPrint(
        '[patient_auth.reset] AuthException status=${error.statusCode} '
        'code=${error.code}',
      );
      return PatientAuthResult(
        PatientAuthStatus.failed,
        arabicAuthFailure(
          error.message,
          code: error.code,
          status: error.statusCode,
        ),
      );
    }
  }

  @override
  Future<PatientAuthResult> updatePassword({required String password}) async {
    if (password.length < 8) {
      return const PatientAuthResult(
        PatientAuthStatus.failed,
        'كلمة المرور لازم تكون 8 أحرف على الأقل.',
      );
    }
    if (isClinicAdminEmail(_client.auth.currentUser?.email)) {
      return const PatientAuthResult(
        PatientAuthStatus.failed,
        patientAdminEmailRejectedMessage,
      );
    }
    try {
      await _client.auth.updateUser(UserAttributes(password: password));
      return const PatientAuthResult(
        PatientAuthStatus.signedIn,
        'تم تعيين كلمة المرور. تقدر تكمل إلى ملفك الصحي.',
      );
    } on AuthException catch (error) {
      return PatientAuthResult(
        PatientAuthStatus.failed,
        arabicAuthFailure(
          error.message,
          code: error.code,
          status: error.statusCode,
        ),
      );
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> deleteAccount() async {
    final blocked = patientAccountDeletionBlockedReason(
      _client.auth.currentUser?.email,
    );
    if (blocked != null) {
      throw StateError(blocked);
    }
    await completePatientAccountDeletion(
      invoke: () async {
        final response = await _client.functions.invoke(
          'patient-account',
          body: {'action': 'delete_own'},
        );
        return response.data;
      },
      signOut: () => _client.auth.signOut(),
    );
  }
}
