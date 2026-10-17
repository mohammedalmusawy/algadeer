import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/doctor_item.dart';

/// جلسة قصيرة في الذاكرة فقط. لا تُحفظ في التخزين المحلي.
class DoctorCardSession {
  const DoctorCardSession({
    required this.entityType,
    required this.entityId,
    required this.role,
    required this.token,
    required this.expiresAt,
    this.permissions = const [],
  });

  final String entityType;
  final String entityId;
  final String role;
  final String token;
  final int expiresAt;
  final List<String> permissions;

  String get doctorId => entityId;

  bool get isAdmin => role == 'admin';

  bool allows(String key) => isAdmin || permissions.contains(key);
}

class EntityOwnerPreview {
  const EntityOwnerPreview({required this.mode, this.waitSeconds = 0, this.message});

  final String mode;
  final int waitSeconds;
  final String? message;
}

class EntityOwnerAdminState {
  const EntityOwnerAdminState({
    required this.mode,
    required this.permissions,
    this.codeExpiresAt,
    this.activationCode,
    required this.isActive,
    required this.displayOrder,
  });

  final String mode;
  final List<String> permissions;
  final int? codeExpiresAt;
  final String? activationCode;
  final bool isActive;
  final int displayOrder;
}

class DoctorCardEditResult {
  const DoctorCardEditResult({this.doctor, this.deleted = false});

  final DoctorItem? doctor;
  final bool deleted;
}

class DoctorCardAccessException implements Exception {
  const DoctorCardAccessException(this.message, {this.code = 'bad_request'});

  final String message;
  final String code;

  @override
  String toString() => message;
}

class DoctorCardStatus {
  const DoctorCardStatus({
    required this.hasPassword,
    required this.isActive,
    required this.displayOrder,
    this.mode = 'password',
    this.permissions = const [],
  });

  final bool hasPassword;
  final bool isActive;
  final int displayOrder;
  final String mode;
  final List<String> permissions;
}

/// مدد رمز التفعيل اللي تختارها الإدارة (بالدقائق). الخادم يقبل هذي بس.
const ownerCodeTtlChoices = <int, String>{
  30: 'نص ساعة',
  120: 'ساعتين',
  1440: 'يوم كامل',
};
const defaultOwnerCodeTtlMinutes = 120;

/// يستدعي Edge Function. التحقق والصلاحيات هناك، لا في الواجهة.
class DoctorCardAccessClient {
  DoctorCardAccessClient({SupabaseClient? client}) : _override = client;

  final SupabaseClient? _override;

  SupabaseClient get _client => _override ?? Supabase.instance.client;

  Future<EntityOwnerPreview> preview({
    required String entityType,
    required String entityId,
  }) async {
    final data = await _call({
      'action': 'preview',
      'entity_type': entityType,
      'entity_id': entityId,
    });
    return EntityOwnerPreview(
      mode: data['mode']?.toString() ?? 'disabled',
      waitSeconds: int.tryParse('${data['wait_seconds']}') ?? 0,
      message: data['error']?.toString(),
    );
  }

  Future<String> verifyCode({
    required String entityType,
    required String entityId,
    required String code,
  }) async {
    final data = await _call({
      'action': 'verify_code',
      'entity_type': entityType,
      'entity_id': entityId,
      'code': code,
    });
    final token = data['activation_token']?.toString() ?? '';
    if (token.isEmpty) {
      throw const DoctorCardAccessException('رمز التفعيل غير صحيح');
    }
    return token;
  }

  Future<DoctorCardSession> completeActivation({
    required String entityType,
    required String entityId,
    required String activationToken,
    required String newPassword,
  }) async {
    final data = await _call({
      'action': 'complete_activation',
      'entity_type': entityType,
      'entity_id': entityId,
      'token': activationToken,
      'new_password': newPassword,
    });
    return _session(entityType, entityId, data);
  }

  Future<DoctorCardSession> login({
    required String doctorId,
    required String password,
    String entityType = 'doctor',
  }) async {
    final data = await _call({
      'action': 'login',
      'entity_type': entityType,
      'entity_id': doctorId,
      'password': password,
    });
    return _session(entityType, doctorId, data);
  }

  DoctorCardSession _session(
    String entityType,
    String entityId,
    Map<String, dynamic> data,
  ) {
    final token = data['token']?.toString() ?? '';
    final role = data['role']?.toString() ?? '';
    if (token.isEmpty || (role != 'owner' && role != 'admin')) {
      throw const DoctorCardAccessException('تعذر إكمال الطلب. حاول لاحقًا.');
    }
    final raw = data['permissions'];
    final permissions = raw is List
        ? raw.map((item) => item.toString()).toList()
        : const <String>[];
    return DoctorCardSession(
      entityType: entityType,
      entityId: entityId,
      role: role,
      token: token,
      expiresAt: int.tryParse('${data['expires_at']}') ?? 0,
      permissions: permissions,
    );
  }

  Future<void> updateFields({
    required DoctorCardSession session,
    required Map<String, dynamic> fields,
    required int baseRevision,
  }) async {
    await _call({
      'action': 'update',
      'entity_type': session.entityType,
      'entity_id': session.entityId,
      'token': session.token,
      'base_revision': baseRevision,
      'fields': fields,
    });
  }

  Future<String> uploadPhoto({
    required DoctorCardSession session,
    required Uint8List bytes,
    required int baseRevision,
    bool logo = false,
  }) async {
    final data = await _call({
      'action': 'upload_photo',
      'entity_type': session.entityType,
      'entity_id': session.entityId,
      'token': session.token,
      'base_revision': baseRevision,
      'image_base64': base64Encode(bytes),
      if (logo) 'logo': true,
    });
    final url = data['image_url']?.toString() ?? '';
    if (url.isEmpty) {
      throw const DoctorCardAccessException('تعذر رفع الصورة.');
    }
    return url;
  }

  Future<void> changePassword({
    required DoctorCardSession session,
    required String oldPassword,
    required String newPassword,
  }) async {
    await _call({
      'action': 'change_password',
      'entity_type': session.entityType,
      'entity_id': session.entityId,
      'token': session.token,
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  Future<EntityOwnerAdminState> adminConfigure({
    required String entityType,
    required String entityId,
    required bool enabled,
    List<String>? permissions,
    bool reset = false,
    bool reissue = false,
    String? cardToken,
    int? codeTtlMinutes,
  }) async {
    final body = <String, dynamic>{
      'action': 'admin_configure',
      'entity_type': entityType,
      'entity_id': entityId,
      'enabled': enabled,
      'reset': reset,
      'reissue': reissue,
    };
    if (permissions != null) body['permissions'] = permissions;
    if (cardToken != null) body['token'] = cardToken;
    if (codeTtlMinutes != null) body['code_ttl_minutes'] = codeTtlMinutes;
    final data = await _call(body);
    return _adminState(data);
  }

  Future<EntityOwnerAdminState> adminStatus({
    required String entityType,
    required String entityId,
    String? cardToken,
  }) async {
    final body = <String, dynamic>{
      'action': 'admin_status',
      'entity_type': entityType,
      'entity_id': entityId,
    };
    if (cardToken != null) body['token'] = cardToken;
    return _adminState(await _call(body));
  }

  EntityOwnerAdminState _adminState(Map<String, dynamic> data) {
    final raw = data['permissions'];
    return EntityOwnerAdminState(
      mode: data['mode']?.toString() ?? 'disabled',
      permissions: raw is List
          ? raw.map((item) => item.toString()).toList()
          : const [],
      codeExpiresAt: int.tryParse('${data['expires_at'] ?? data['code_expires_at']}'),
      activationCode: data['activation_code']?.toString(),
      isActive: data['is_active'] != false,
      displayOrder: int.tryParse('${data['display_order']}') ?? 0,
    );
  }

  Future<DoctorCardStatus> adminStatusForSession(DoctorCardSession session) async {
    final state = await adminStatus(
      entityType: session.entityType,
      entityId: session.entityId,
      cardToken: session.token,
    );
    return DoctorCardStatus(
      hasPassword: state.mode == 'password',
      isActive: state.isActive,
      displayOrder: state.displayOrder,
      mode: state.mode,
      permissions: state.permissions,
    );
  }

  Future<void> upsertPackage({
    required DoctorCardSession session,
    String? packageId,
    required Map<String, dynamic> package,
    int? baseRevision,
  }) async {
    await _call({
      'action': 'upsert_package',
      'entity_type': session.entityType,
      'entity_id': session.entityId,
      'token': session.token,
      if (packageId != null && packageId.isNotEmpty) 'package_id': packageId,
      'base_revision': ?baseRevision,
      'package': package,
    });
  }

  Future<void> deletePackage({
    required DoctorCardSession session,
    required String packageId,
  }) async {
    await _call({
      'action': 'delete_package',
      'entity_type': session.entityType,
      'entity_id': session.entityId,
      'token': session.token,
      'package_id': packageId,
    });
  }

  Future<String> uploadPharmacyAsset({
    required DoctorCardSession session,
    required Uint8List bytes,
    bool entityPhoto = false,
    int? baseRevision,
  }) async {
    final data = await _call({
      'action': 'upload_photo',
      'entity_type': session.entityType,
      'entity_id': session.entityId,
      'token': session.token,
      'asset_only': !entityPhoto,
      'base_revision': ?baseRevision,
      'image_base64': base64Encode(bytes),
    });
    final url = data['image_url']?.toString() ?? '';
    if (url.isEmpty) {
      throw const DoctorCardAccessException('تعذر رفع الصورة.');
    }
    return url;
  }

  Future<String> uploadPackageImage({
    required DoctorCardSession session,
    required Uint8List bytes,
  }) async {
    final data = await _call({
      'action': 'upload_photo',
      'entity_type': session.entityType,
      'entity_id': session.entityId,
      'token': session.token,
      'package_image': true,
      'image_base64': base64Encode(bytes),
    });
    final url = data['image_url']?.toString() ?? '';
    if (url.isEmpty) {
      throw const DoctorCardAccessException('تعذر رفع الصورة.');
    }
    return url;
  }

  Future<void> adminDelete(DoctorCardSession session) async {
    await _call({
      'action': 'delete',
      'entity_type': session.entityType,
      'entity_id': session.entityId,
      'token': session.token,
    });
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    try {
      final response = await _client.functions.invoke(
        'doctor-card-access',
        body: body,
      );
      final data = response.data;
      if (data is Map && data['ok'] == true) {
        return Map<String, dynamic>.from(data);
      }
      throw DoctorCardAccessException(_errorText(data));
    } on DoctorCardAccessException {
      rethrow;
    } on FunctionException catch (error) {
      throw DoctorCardAccessException(
        _errorText(error.details, status: error.status),
        code: _code(error.details),
      );
    } catch (_) {
      throw const DoctorCardAccessException(
        'تعذر الاتصال بخدمة التحقق. حاول لاحقًا.',
      );
    }
  }

  String _code(Object? details) {
    if (details is Map && details['code'] != null) {
      return details['code'].toString();
    }
    return 'bad_request';
  }

  String _errorText(Object? details, {int? status}) {
    if (details is Map && details['error'] is String) {
      final text = (details['error'] as String).trim();
      if (text.isNotEmpty) return text;
    }
    if (status == 404) {
      return 'خدمة التحقق غير جاهزة. راجع إعداد المشروع.';
    }
    return 'تعذر إكمال الطلب. حاول لاحقًا.';
  }
}
