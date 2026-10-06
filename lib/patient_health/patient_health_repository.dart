import 'dart:math';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'patient_health_models.dart';

abstract class PatientHealthRepository {
  String get userId;

  Future<PatientHealthSnapshot> load();

  Future<void> saveConsent({required String displayName, required DateTime at});

  Future<PatientCondition> saveCondition(PatientCondition condition);

  Future<void> deleteCondition(String id);

  Future<BpReading> saveBp(BpReading reading);

  Future<void> deleteBp(String id);

  Future<GlucoseReading> saveGlucose(GlucoseReading reading);

  Future<void> deleteGlucose(String id);

  Future<ThalassemiaEvent> saveEvent(ThalassemiaEvent event);

  Future<void> deleteEvent(String id);

  Future<HealthAttachment> addAttachment({
    required String conditionId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  });

  Future<Uint8List> readAttachment(String id);

  Future<void> deleteAttachment(String id);

  Future<void> deleteOwnFile();
}

class PatientFileDatabase {
  final profiles = <String, PatientHealthProfile>{};
  final conditions = <PatientCondition>[];
  final bpReadings = <BpReading>[];
  final glucoseReadings = <GlucoseReading>[];
  final events = <ThalassemiaEvent>[];
  final attachments = <HealthAttachment>[];
  final attachmentBytes = <String, Uint8List>{};
}

/// يحاكي RLS: كل عملية تُرفض إن لم يكن السجل لمالك الجلسة، حتى بالطلب المباشر.
class MemoryPatientHealthRepository implements PatientHealthRepository {
  MemoryPatientHealthRepository(this.userId, this.db);

  @override
  final String userId;
  final PatientFileDatabase db;

  void _own(String ownerId) {
    if (ownerId != userId) throw const PatientAccessDenied();
  }

  @override
  Future<PatientHealthSnapshot> load() async {
    return PatientHealthSnapshot(
      profile: db.profiles[userId],
      conditions: [for (final row in db.conditions) if (row.userId == userId) row],
      bpReadings: [for (final row in db.bpReadings) if (row.userId == userId) row],
      glucoseReadings: [
        for (final row in db.glucoseReadings)
          if (row.userId == userId) row,
      ],
      events: [for (final row in db.events) if (row.userId == userId) row],
      attachments: [
        for (final row in db.attachments)
          if (row.userId == userId) row,
      ],
    );
  }

  @override
  Future<void> saveConsent({
    required String displayName,
    required DateTime at,
  }) async {
    db.profiles[userId] = PatientHealthProfile(
      userId: userId,
      displayName: displayName.trim(),
      consentAt: at,
    );
  }

  @override
  Future<PatientCondition> saveCondition(PatientCondition condition) async {
    _own(condition.userId);
    final index = db.conditions.indexWhere((row) => row.id == condition.id);
    if (index >= 0) {
      _own(db.conditions[index].userId);
      db.conditions[index] = condition;
    } else {
      db.conditions.add(condition);
    }
    return condition;
  }

  @override
  Future<void> deleteCondition(String id) async {
    final row = db.conditions.cast<PatientCondition?>().firstWhere(
          (item) => item!.id == id,
          orElse: () => null,
        );
    if (row == null) throw const PatientAccessDenied();
    _own(row.userId);
    db.conditions.removeWhere((item) => item.id == id);
    db.bpReadings.removeWhere((item) => item.conditionId == id);
    db.glucoseReadings.removeWhere((item) => item.conditionId == id);
    db.events.removeWhere((item) => item.conditionId == id);
    final attached = [
      for (final item in db.attachments)
        if (item.conditionId == id) item,
    ];
    for (final item in attached) {
      db.attachmentBytes.remove(item.storagePath);
    }
    db.attachments.removeWhere((item) => item.conditionId == id);
  }

  @override
  Future<BpReading> saveBp(BpReading reading) async {
    _own(reading.userId);
    _requireOwnCondition(reading.conditionId, childUserId: reading.userId);
    final index = db.bpReadings.indexWhere((row) => row.id == reading.id);
    if (index >= 0) {
      _own(db.bpReadings[index].userId);
      db.bpReadings[index] = reading;
    } else {
      db.bpReadings.add(reading);
    }
    return reading;
  }

  @override
  Future<void> deleteBp(String id) async {
    final row = db.bpReadings.cast<BpReading?>().firstWhere(
          (item) => item!.id == id,
          orElse: () => null,
        );
    if (row == null) throw const PatientAccessDenied();
    _own(row.userId);
    db.bpReadings.removeWhere((item) => item.id == id);
  }

  @override
  Future<GlucoseReading> saveGlucose(GlucoseReading reading) async {
    _own(reading.userId);
    _requireOwnCondition(reading.conditionId, childUserId: reading.userId);
    final index = db.glucoseReadings.indexWhere((row) => row.id == reading.id);
    if (index >= 0) {
      _own(db.glucoseReadings[index].userId);
      db.glucoseReadings[index] = reading;
    } else {
      db.glucoseReadings.add(reading);
    }
    return reading;
  }

  @override
  Future<void> deleteGlucose(String id) async {
    final row = db.glucoseReadings.cast<GlucoseReading?>().firstWhere(
          (item) => item!.id == id,
          orElse: () => null,
        );
    if (row == null) throw const PatientAccessDenied();
    _own(row.userId);
    db.glucoseReadings.removeWhere((item) => item.id == id);
  }

  @override
  Future<ThalassemiaEvent> saveEvent(ThalassemiaEvent event) async {
    _own(event.userId);
    _requireOwnCondition(event.conditionId, childUserId: event.userId);
    final index = db.events.indexWhere((row) => row.id == event.id);
    if (index >= 0) {
      _own(db.events[index].userId);
      db.events[index] = event;
    } else {
      db.events.add(event);
    }
    return event;
  }

  @override
  Future<void> deleteEvent(String id) async {
    final row = db.events.cast<ThalassemiaEvent?>().firstWhere(
          (item) => item!.id == id,
          orElse: () => null,
        );
    if (row == null) throw const PatientAccessDenied();
    _own(row.userId);
    db.events.removeWhere((item) => item.id == id);
  }

  @override
  Future<HealthAttachment> addAttachment({
    required String conditionId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    _requireOwnCondition(conditionId, childUserId: userId);
    if (contentType.trim().isEmpty || bytes.isEmpty) {
      throw StateError('المرفق فارغ.');
    }
    final id = newHealthId();
    final path = '$userId/$id';
    final row = HealthAttachment(
      id: id,
      userId: userId,
      conditionId: conditionId,
      storagePath: path,
      fileName: fileName,
      createdAt: DateTime.now().toUtc(),
    );
    db.attachments.add(row);
    db.attachmentBytes[path] = Uint8List.fromList(bytes);
    return row;
  }

  @override
  Future<Uint8List> readAttachment(String id) async {
    final row = db.attachments.cast<HealthAttachment?>().firstWhere(
          (item) => item!.id == id,
          orElse: () => null,
        );
    if (row == null) throw const PatientAccessDenied();
    _own(row.userId);
    final bytes = db.attachmentBytes[row.storagePath];
    if (bytes == null) throw const PatientAccessDenied();
    return bytes;
  }

  @override
  Future<void> deleteAttachment(String id) async {
    final row = db.attachments.cast<HealthAttachment?>().firstWhere(
          (item) => item!.id == id,
          orElse: () => null,
        );
    if (row == null) throw const PatientAccessDenied();
    _own(row.userId);
    db.attachmentBytes.remove(row.storagePath);
    db.attachments.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> deleteOwnFile() async {
    db.profiles.remove(userId);
    final conditionIds = [
      for (final row in db.conditions)
        if (row.userId == userId) row.id,
    ];
    db.conditions.removeWhere((row) => row.userId == userId);
    db.bpReadings.removeWhere((row) => row.userId == userId);
    db.glucoseReadings.removeWhere((row) => row.userId == userId);
    db.events.removeWhere((row) => row.userId == userId);
    final paths = [
      for (final row in db.attachments)
        if (row.userId == userId) row.storagePath,
    ];
    for (final path in paths) {
      db.attachmentBytes.remove(path);
    }
    db.attachments.removeWhere((row) => row.userId == userId);
    for (final id in conditionIds) {
      db.bpReadings.removeWhere((row) => row.conditionId == id);
      db.glucoseReadings.removeWhere((row) => row.conditionId == id);
      db.events.removeWhere((row) => row.conditionId == id);
    }
  }

  void _requireOwnCondition(String conditionId, {String? childUserId}) {
    final row = db.conditions.cast<PatientCondition?>().firstWhere(
          (item) => item!.id == conditionId,
          orElse: () => null,
        );
    if (row == null) throw const PatientAccessDenied();
    _own(row.userId);
    if (childUserId != null && row.userId != childUserId) {
      throw const PatientAccessDenied();
    }
  }
}

class SupabasePatientHealthRepository implements PatientHealthRepository {
  SupabasePatientHealthRepository(this._client, this.userId);

  final SupabaseClient _client;

  @override
  final String userId;

  @override
  Future<PatientHealthSnapshot> load() async {
    final profileRows = await _client
        .from('patient_health_profiles')
        .select()
        .eq('user_id', userId);
    final conditionRows =
        await _client.from('patient_conditions').select().eq('user_id', userId);
    final bpRows =
        await _client.from('patient_bp_readings').select().eq('user_id', userId);
    final glucoseRows = await _client
        .from('patient_glucose_readings')
        .select()
        .eq('user_id', userId);
    final eventRows = await _client
        .from('patient_thalassemia_events')
        .select()
        .eq('user_id', userId);
    final attachmentRows = await _client
        .from('patient_health_attachments')
        .select()
        .eq('user_id', userId);

    PatientHealthProfile? profile;
    final profiles = _maps(profileRows);
    if (profiles.isNotEmpty) {
      final row = profiles.first;
      _expectOwner(row['user_id']);
      profile = PatientHealthProfile(
        userId: userId,
        displayName: row['display_name']?.toString() ?? '',
        consentAt: DateTime.parse(row['consent_at'].toString()),
      );
    }

    return PatientHealthSnapshot(
      profile: profile,
      conditions: [
        for (final row in _maps(conditionRows))
          if (_isOwner(row['user_id'])) _condition(row),
      ],
      bpReadings: [
        for (final row in _maps(bpRows))
          if (_isOwner(row['user_id'])) _bp(row),
      ],
      glucoseReadings: [
        for (final row in _maps(glucoseRows))
          if (_isOwner(row['user_id'])) _glucose(row),
      ],
      events: [
        for (final row in _maps(eventRows))
          if (_isOwner(row['user_id'])) _event(row),
      ],
      attachments: [
        for (final row in _maps(attachmentRows))
          if (_isOwner(row['user_id'])) _attachment(row),
      ],
    );
  }

  @override
  Future<void> saveConsent({
    required String displayName,
    required DateTime at,
  }) async {
    await _client.from('patient_health_profiles').upsert({
      'user_id': userId,
      'display_name': displayName.trim(),
      'consent_at': at.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<PatientCondition> saveCondition(PatientCondition condition) async {
    _expectOwner(condition.userId);
    final payload = {
      'id': condition.id,
      'user_id': userId,
      'kind': kindToDb(condition.kind),
      'label': condition.label,
      'thalassemia_type': condition.thalassemiaType,
      'prescribed_treatment': condition.prescribedTreatment,
      'reviews_note': condition.reviewsNote,
      'notes': condition.notes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final rows = await _client.from('patient_conditions').upsert(payload).select();
    final saved = _maps(rows);
    if (saved.isEmpty) throw const PatientAccessDenied();
    return _condition(saved.first);
  }

  @override
  Future<void> deleteCondition(String id) async {
    final rows = await _client
        .from('patient_conditions')
        .delete()
        .eq('id', id)
        .eq('user_id', userId)
        .select();
    if (_maps(rows).isEmpty) throw const PatientAccessDenied();
  }

  @override
  Future<BpReading> saveBp(BpReading reading) async {
    _expectOwner(reading.userId);
    final rows = await _client.from('patient_bp_readings').upsert({
      'id': reading.id,
      'user_id': userId,
      'condition_id': reading.conditionId,
      'systolic': reading.systolic,
      'diastolic': reading.diastolic,
      'pulse': reading.pulse,
      'measured_at': reading.measuredAt.toUtc().toIso8601String(),
    }).select();
    final saved = _maps(rows);
    if (saved.isEmpty) throw const PatientAccessDenied();
    return _bp(saved.first);
  }

  @override
  Future<void> deleteBp(String id) async {
    final rows = await _client
        .from('patient_bp_readings')
        .delete()
        .eq('id', id)
        .eq('user_id', userId)
        .select();
    if (_maps(rows).isEmpty) throw const PatientAccessDenied();
  }

  @override
  Future<GlucoseReading> saveGlucose(GlucoseReading reading) async {
    _expectOwner(reading.userId);
    final rows = await _client.from('patient_glucose_readings').upsert({
      'id': reading.id,
      'user_id': userId,
      'condition_id': reading.conditionId,
      'value': reading.value,
      'unit': unitToDb(reading.unit),
      'timing': timingToDb(reading.timing),
      'measured_at': reading.measuredAt.toUtc().toIso8601String(),
    }).select();
    final saved = _maps(rows);
    if (saved.isEmpty) throw const PatientAccessDenied();
    return _glucose(saved.first);
  }

  @override
  Future<void> deleteGlucose(String id) async {
    final rows = await _client
        .from('patient_glucose_readings')
        .delete()
        .eq('id', id)
        .eq('user_id', userId)
        .select();
    if (_maps(rows).isEmpty) throw const PatientAccessDenied();
  }

  @override
  Future<ThalassemiaEvent> saveEvent(ThalassemiaEvent event) async {
    _expectOwner(event.userId);
    final rows = await _client.from('patient_thalassemia_events').upsert({
      'id': event.id,
      'user_id': userId,
      'condition_id': event.conditionId,
      'event_kind': eventKindToDb(event.kind),
      'title': event.title,
      'details': event.details,
      'occurred_at': event.occurredAt.toUtc().toIso8601String(),
    }).select();
    final saved = _maps(rows);
    if (saved.isEmpty) throw const PatientAccessDenied();
    return _event(saved.first);
  }

  @override
  Future<void> deleteEvent(String id) async {
    final rows = await _client
        .from('patient_thalassemia_events')
        .delete()
        .eq('id', id)
        .eq('user_id', userId)
        .select();
    if (_maps(rows).isEmpty) throw const PatientAccessDenied();
  }

  @override
  Future<HealthAttachment> addAttachment({
    required String conditionId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final id = newHealthId();
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final path = '$userId/$id${safeName.isEmpty ? '' : '_$safeName'}';
    await _client.storage.from('patient-health').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    try {
      final rows = await _client.from('patient_health_attachments').insert({
        'id': id,
        'user_id': userId,
        'condition_id': conditionId,
        'storage_path': path,
        'file_name': fileName,
      }).select();
      final saved = _maps(rows);
      if (saved.isEmpty) throw const PatientAccessDenied();
      return _attachment(saved.first);
    } catch (error) {
      await _client.storage.from('patient-health').remove([path]);
      rethrow;
    }
  }

  @override
  Future<Uint8List> readAttachment(String id) async {
    final rows = await _client
        .from('patient_health_attachments')
        .select()
        .eq('id', id)
        .eq('user_id', userId);
    final saved = _maps(rows);
    if (saved.isEmpty) throw const PatientAccessDenied();
    final path = saved.first['storage_path'].toString();
    if (!path.startsWith('$userId/')) throw const PatientAccessDenied();
    return _client.storage.from('patient-health').download(path);
  }

  @override
  Future<void> deleteAttachment(String id) async {
    final rows = await _client
        .from('patient_health_attachments')
        .delete()
        .eq('id', id)
        .eq('user_id', userId)
        .select();
    final saved = _maps(rows);
    if (saved.isEmpty) throw const PatientAccessDenied();
    final path = saved.first['storage_path']?.toString() ?? '';
    if (path.startsWith('$userId/')) {
      await _client.storage.from('patient-health').remove([path]);
    }
  }

  @override
  Future<void> deleteOwnFile() async {
    final attachments = await _client
        .from('patient_health_attachments')
        .select('storage_path')
        .eq('user_id', userId);
    final paths = [
      for (final row in _maps(attachments))
        if ((row['storage_path']?.toString() ?? '').startsWith('$userId/'))
          row['storage_path'].toString(),
    ];
    if (paths.isNotEmpty) {
      await _client.storage.from('patient-health').remove(paths);
    }
    await _client.from('patient_conditions').delete().eq('user_id', userId);
    await _client.from('patient_health_profiles').delete().eq('user_id', userId);
  }

  bool _isOwner(Object? value) => value?.toString() == userId;

  void _expectOwner(Object? value) {
    if (!_isOwner(value)) throw const PatientAccessDenied();
  }

  List<Map<String, dynamic>> _maps(Object? rows) {
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  PatientCondition _condition(Map<String, dynamic> row) {
    _expectOwner(row['user_id']);
    return PatientCondition(
      id: row['id'].toString(),
      userId: userId,
      kind: kindFromDb(row['kind']?.toString() ?? ''),
      label: row['label']?.toString() ?? '',
      thalassemiaType: row['thalassemia_type']?.toString() ?? '',
      prescribedTreatment: row['prescribed_treatment']?.toString() ?? '',
      reviewsNote: row['reviews_note']?.toString() ?? '',
      notes: row['notes']?.toString() ?? '',
      createdAt: DateTime.parse(row['created_at'].toString()),
      updatedAt: DateTime.parse(row['updated_at'].toString()),
    );
  }

  BpReading _bp(Map<String, dynamic> row) {
    _expectOwner(row['user_id']);
    return BpReading(
      id: row['id'].toString(),
      userId: userId,
      conditionId: row['condition_id'].toString(),
      systolic: (row['systolic'] as num).toInt(),
      diastolic: (row['diastolic'] as num).toInt(),
      pulse: row['pulse'] == null ? null : (row['pulse'] as num).toInt(),
      measuredAt: DateTime.parse(row['measured_at'].toString()),
    );
  }

  GlucoseReading _glucose(Map<String, dynamic> row) {
    _expectOwner(row['user_id']);
    return GlucoseReading(
      id: row['id'].toString(),
      userId: userId,
      conditionId: row['condition_id'].toString(),
      value: (row['value'] as num).toDouble(),
      unit: unitFromDb(row['unit']?.toString() ?? ''),
      timing: timingFromDb(row['timing']?.toString() ?? ''),
      measuredAt: DateTime.parse(row['measured_at'].toString()),
    );
  }

  ThalassemiaEvent _event(Map<String, dynamic> row) {
    _expectOwner(row['user_id']);
    return ThalassemiaEvent(
      id: row['id'].toString(),
      userId: userId,
      conditionId: row['condition_id'].toString(),
      kind: eventKindFromDb(row['event_kind']?.toString() ?? ''),
      title: row['title']?.toString() ?? '',
      details: row['details']?.toString() ?? '',
      occurredAt: DateTime.parse(row['occurred_at'].toString()),
    );
  }

  HealthAttachment _attachment(Map<String, dynamic> row) {
    _expectOwner(row['user_id']);
    return HealthAttachment(
      id: row['id'].toString(),
      userId: userId,
      conditionId: row['condition_id']?.toString() ?? '',
      storagePath: row['storage_path']?.toString() ?? '',
      fileName: row['file_name']?.toString() ?? '',
      createdAt: DateTime.parse(row['created_at'].toString()),
    );
  }
}

String newHealthId() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String patientHealthErrorMessage(Object error) {
  if (error is PatientAccessDenied) {
    return 'ما تقدر توصل لهالسجل.';
  }
  if (error is PostgrestException &&
      (error.code == 'PGRST205' || error.code == '42P01')) {
    return 'جداول الملف الصحي غير مطبّقة بعد. نفّذ ملف '
        'patient_health_file_schema.sql في Supabase ثم أعد المحاولة.';
  }
  if (error is StorageException) {
    return 'تعذر التعامل مع المرفق. تأكد أن مستودع patient-health خاص ومطبّق.';
  }
  return 'تعذر إكمال الطلب. حاول لاحقًا.';
}
