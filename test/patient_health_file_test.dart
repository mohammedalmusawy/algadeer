import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/patient_health/attachment_view.dart';
import 'package:ghadeer_clinic/patient_health/card_export.dart';
import 'package:ghadeer_clinic/patient_health/follow_up_card.dart';
import 'package:ghadeer_clinic/patient_health/follow_up_card_page.dart';
import 'package:ghadeer_clinic/patient_health/patient_auth.dart';
import 'package:ghadeer_clinic/patient_health/patient_auth_page.dart';
import 'package:ghadeer_clinic/patient_health/patient_health_models.dart';
import 'package:ghadeer_clinic/patient_health/patient_health_page.dart';
import 'package:ghadeer_clinic/patient_health/patient_health_repository.dart';
import 'package:ghadeer_clinic/patient_health/patient_health_validation.dart';
import 'package:ghadeer_clinic/services/admin_password_change_page.dart';

final Uint8List _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  final now = DateTime(2026, 10, 4, 18, 30);

  test('الأرقام العربية والتواريخ والوحدات تُفحص بلا حكم طبي', () {
    expect(parseHealthInt('١٢٨'), 128);
    expect(parseHealthDouble('٥٫٦'), 5.6);
    expect(
      validateBloodPressure(
        systolic: '١٢٨',
        diastolic: '٨٢',
        pulse: '٧٠',
        measuredAt: now,
        now: now,
      ),
      isNull,
    );
    expect(
      validateBloodPressure(
        systolic: '80',
        diastolic: '120',
        measuredAt: now,
        now: now,
      ),
      'الانقباضي لازم يكون أعلى من الانبساطي.',
    );
    expect(
      validateGlucose(
        value: '110',
        unit: GlucoseUnit.mgDl,
        measuredAt: now,
        now: now,
      ),
      isNull,
    );
    expect(
      validateGlucose(
        value: '110',
        unit: GlucoseUnit.mmolL,
        measuredAt: now,
        now: now,
      ),
      isNotNull,
    );
    expect(
      validateMeasuredAt(now.add(const Duration(days: 1)), now),
      isNotNull,
    );
    expect(
      validateBloodPressure(
        systolic: '190',
        diastolic: '100',
        measuredAt: now,
        now: now,
      ),
      isNull,
    );
  });

  test('حسابان: الطلب المباشر على سجل الآخر يُرفض', () async {
    final db = PatientFileDatabase();
    final first = MemoryPatientHealthRepository('user-a', db);
    final second = MemoryPatientHealthRepository('user-b', db);
    await first.saveConsent(displayName: 'أحمد', at: now);
    final condition = await first.saveCondition(
      PatientCondition(
        id: 'cond-a',
        userId: 'user-a',
        kind: ConditionKind.hypertension,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final reading = await first.saveBp(
      BpReading(
        id: 'bp-a',
        userId: 'user-a',
        conditionId: condition.id,
        systolic: 120,
        diastolic: 80,
        measuredAt: now,
      ),
    );
    await first.addAttachment(
      conditionId: condition.id,
      fileName: 'lab.png',
      bytes: Uint8List.fromList([1, 2, 3]),
      contentType: 'image/png',
    );

    expect((await second.load()).conditions, isEmpty);
    expect((await second.load()).bpReadings, isEmpty);
    expect(() => second.deleteBp(reading.id), throwsA(isA<PatientAccessDenied>()));
    expect(() => second.deleteCondition(condition.id), throwsA(isA<PatientAccessDenied>()));
    expect(
      () => second.readAttachment((db.attachments.single).id),
      throwsA(isA<PatientAccessDenied>()),
    );
    expect(
      () => second.saveBp(
        BpReading(
          id: 'bp-stolen',
          userId: 'user-a',
          conditionId: condition.id,
          systolic: 10,
          diastolic: 5,
          measuredAt: now,
        ),
      ),
      throwsA(isA<PatientAccessDenied>()),
    );
    await second.saveConsent(displayName: 'ليث', at: now);
    final otherCondition = await second.saveCondition(
      PatientCondition(
        id: 'cond-b',
        userId: 'user-b',
        kind: ConditionKind.diabetes,
        createdAt: now,
        updatedAt: now,
      ),
    );
    expect(
      () => first.saveBp(
        BpReading(
          id: 'bp-mismatch',
          userId: 'user-a',
          conditionId: otherCondition.id,
          systolic: 110,
          diastolic: 70,
          measuredAt: now,
        ),
      ),
      throwsA(isA<PatientAccessDenied>()),
    );
    expect(
      () => first.addAttachment(
        conditionId: otherCondition.id,
        fileName: 'other.png',
        bytes: Uint8List.fromList([9, 9, 9]),
        contentType: 'image/png',
      ),
      throwsA(isA<PatientAccessDenied>()),
    );
    expect(db.bpReadings.single.systolic, 120);
    expect(
      () => first.saveBp(
        BpReading(
          id: reading.id,
          userId: reading.userId,
          conditionId: otherCondition.id,
          systolic: reading.systolic,
          diastolic: reading.diastolic,
          measuredAt: reading.measuredAt,
        ),
      ),
      throwsA(isA<PatientAccessDenied>()),
    );
    expect(db.bpReadings.single.conditionId, condition.id);
    await second.deleteOwnFile();
    expect(db.bpReadings, isNotEmpty);
    await first.deleteOwnFile();
    expect(db.bpReadings, isEmpty);
    expect(db.profiles.containsKey('user-a'), isFalse);
    expect(db.attachmentBytes, isEmpty);
  });

  test('البطاقة تعرض مرضاً وفترة واسماً حسب اختيار المريض', () {
    final snapshot = PatientHealthSnapshot(
      profile: PatientHealthProfile(
        userId: 'user-a',
        displayName: 'أحمد',
        consentAt: now,
      ),
      conditions: [
        PatientCondition(
          id: 'bp',
          userId: 'user-a',
          kind: ConditionKind.hypertension,
          createdAt: now,
          updatedAt: now,
        ),
        PatientCondition(
          id: 'sugar',
          userId: 'user-a',
          kind: ConditionKind.diabetes,
          createdAt: now,
          updatedAt: now,
        ),
        PatientCondition(
          id: 'other-user',
          userId: 'user-b',
          kind: ConditionKind.hypertension,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      bpReadings: [
        BpReading(
          id: 'old',
          userId: 'user-a',
          conditionId: 'bp',
          systolic: 150,
          diastolic: 95,
          measuredAt: now.subtract(const Duration(days: 40)),
        ),
        BpReading(
          id: 'new',
          userId: 'user-a',
          conditionId: 'bp',
          systolic: 128,
          diastolic: 82,
          measuredAt: now.subtract(const Duration(days: 2)),
        ),
        BpReading(
          id: 'foreign',
          userId: 'user-b',
          conditionId: 'bp',
          systolic: 200,
          diastolic: 100,
          measuredAt: now,
        ),
      ],
      glucoseReadings: [
        GlucoseReading(
          id: 'g1',
          userId: 'user-a',
          conditionId: 'sugar',
          value: 140,
          unit: GlucoseUnit.mgDl,
          timing: GlucoseTiming.fasting,
          measuredAt: now,
        ),
      ],
    );

    final month = buildFollowUpCard(
      userId: 'user-a',
      snapshot: snapshot,
      selection: FollowUpSelection(
        conditionId: 'bp',
        period: FollowUpPeriod.days30,
        issuedAt: now,
        showName: false,
      ),
    );
    expect(month.patientName, isNull);
    expect(month.readings.map((r) => r.valueLabel).join('\n'), contains('128/82'));
    expect(month.readings.map((r) => r.valueLabel).join('\n'), isNot(contains('150/95')));
    expect(month.readings.map((r) => r.valueLabel).join('\n'), isNot(contains('140')));
    expect(month.readings.map((r) => r.valueLabel).join('\n'), isNot(contains('200/100')));
    expect(month.readings.join(), isNot(contains('أحمد')));

    final named = buildFollowUpCard(
      userId: 'user-a',
      snapshot: snapshot,
      selection: FollowUpSelection(
        conditionId: 'sugar',
        period: FollowUpPeriod.days7,
        issuedAt: now,
        showName: true,
      ),
    );
    expect(named.patientName, 'أحمد');
    expect(named.readings.single.unitLabel, contains('ملغ/دل'));
    expect(
      () => buildFollowUpCard(
        userId: 'user-a',
        snapshot: snapshot,
        selection: FollowUpSelection(
          conditionId: 'other-user',
          period: FollowUpPeriod.all,
          issuedAt: now,
        ),
      ),
      throwsA(isA<PatientAccessDenied>()),
    );
  });

  test('رسائل الدخول لا تدّعي وصول البريد', () {
    expect(patientConfirmationPendingMessage, contains('لم نتحقق'));
    expect(patientResetRequestedMessage, contains('لم نتحقق'));
    expect(patientConfirmationPendingMessage, isNot(contains('تم الدخول')));
    expect(patientConfirmationPendingMessage, isNot(contains('SMTP')));
    expect(patientConfirmationPendingMessage, isNot(contains('Supabase')));
    expect(patientResetRequestedMessage, isNot(contains('SMTP')));
    expect(patientResetRequestedMessage, isNot(contains('Redirect')));
    expect(patientResetRequestedMessage, isNot(contains('Supabase')));
    expect(arabicAuthFailure('rate limit'), isNot(contains('SMTP')));
    expect(
      arabicAuthFailure('x', code: 'over_email_send_rate_limit', status: '429'),
      contains('حاول بعد قليل'),
    );
    expect(validatePatientCredentials(kAdminEmail, '12345678'), isNotNull);
    expect(arabicAuthFailure('Email not confirmed'), contains('غير مؤكد'));
    expect(
      isPatientHealthReturnUri(Uri.parse('https://example/#/patient-health')),
      isTrue,
    );
    expect(
      isAdminRecoveryReturnUri(Uri.parse('https://example/#/admin-recovery')),
      isTrue,
    );
    expect(
      patientAuthRedirectTo(web: false),
      isNot(adminPasswordResetRedirectTo(web: false)),
    );
    expect(patientAuthRedirectTo(web: false), contains('/patient-health'));
    expect(adminPasswordResetRedirectTo(web: false), contains('/admin-recovery'));
  });

  test('مخطط SQL يقصر السجلات على المالك ويبقي المرفقات خاصة', () {
    final sql = File('supabase/patient_health_file_schema.sql').readAsStringSync();
    for (final table in [
      'patient_health_profiles',
      'patient_conditions',
      'patient_bp_readings',
      'patient_glucose_readings',
      'patient_thalassemia_events',
      'patient_health_attachments',
    ]) {
      expect(sql, contains('alter table public.$table enable row level security'));
      expect(sql, contains('alter table public.$table force row level security'));
    }
    expect('auth.uid() = user_id'.allMatches(sql).length, greaterThanOrEqualTo(6));
    expect(sql.contains('using (public.is_clinic_admin())'), isFalse);
    expect(sql, contains("values ('patient-health', 'patient-health', false)"));
    expect(sql, contains('use_storage_api'));
    expect(sql.contains('delete from storage.objects'), isFalse);
    expect(sql.contains('delete from auth.users'), isFalse);
    expect(sql, contains('admin_forbidden'));
    expect(sql.contains('grant select') && sql.contains('to anon'), isFalse);
  });

  test('التصحيح يربط condition_id بنفس user_id ويمنع حذف storage.objects', () {
    final sql =
        File('supabase/patient_health_hardening.sql').readAsStringSync();
    expect(sql, contains('patient_bp_condition_same_user'));
    expect(sql, contains('patient_glucose_condition_same_user'));
    expect(sql, contains('patient_thalassemia_condition_same_user'));
    expect(sql, contains('patient_attachments_condition_same_user'));
    expect(sql, contains('foreign key (condition_id, user_id)'));
    expect(sql, contains('user_id_immutable'));
    expect(sql, contains('set search_path = public'));
    expect(sql.contains('delete from storage.objects'), isFalse);
    expect(sql, contains('use_storage_api'));
    expect(sql, contains('admin_forbidden'));
    expect(
      File('lib/patient_health/patient_auth.dart').readAsStringSync(),
      contains("'patient-account'"),
    );
    expect(
      File('supabase/app_ui_icons_schema.sql').readAsStringSync(),
      contains('using (public.is_clinic_admin())'),
    );
    expect(
      File('supabase/security_harden_zero_impact.sql').readAsStringSync(),
      contains("'public.app_ui_icons'"),
    );
    expect(
      File('supabase/security_harden_zero_impact.sql').readAsStringSync(),
      contains("'doctors'"),
    );
    expect(
      File('supabase/admin_write_policy_correction.sql').readAsStringSync(),
      contains('Admin upload doctor images 5uiklb_0'),
    );
  });

  test('حساب الإدارة لا يُسمح له بحذف حساب مريض', () {
    expect(
      patientAccountDeletionBlockedReason(kAdminEmail),
      patientAdminEmailRejectedMessage,
    );
    expect(patientAccountDeletionBlockedReason('patient@example.com'), isNull);
  });

  test('حذف الحساب يعيد المحاولة ولا يخرج عند الفشل', () async {
    var invokes = 0;
    var signedOut = false;
    await expectLater(
      completePatientAccountDeletion(
        invoke: () async {
          invokes += 1;
          throw StateError('network');
        },
        signOut: () async {
          signedOut = true;
        },
      ),
      throwsA(isA<StateError>()),
    );
    expect(invokes, 3);
    expect(signedOut, isFalse);

    invokes = 0;
    await completePatientAccountDeletion(
      invoke: () async {
        invokes += 1;
        if (invokes == 1) throw StateError('temp');
        return {'ok': true};
      },
      signOut: () async {
        signedOut = true;
      },
    );
    expect(invokes, 2);
    expect(signedOut, isTrue);
  });

  testWidgets('الموافقة ثم قراءة ضغط بالأرقام العربية', (tester) async {
    final repo = MemoryPatientHealthRepository('user-a', PatientFileDatabase());
    await tester.pumpWidget(
      MaterialApp(
        home: PatientHealthPage(
          repository: repo,
          now: () => now,
          onSignOut: () async {},
          onDeleteAccount: () async {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('أنت دخلتها'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('حفظ الموافقة'));
    await frames(tester);
    await tester.tap(find.text('إضافة مرض'));
    await frames(tester);
    await tester.tap(find.text('متابعة'));
    await frames(tester);
    expect(find.text('الضغط'), findsWidgets);
    await tester.tap(find.text('قراءة ضغط'));
    await frames(tester);
    await tester.enterText(find.byType(TextField).at(0), '١٢٨');
    await tester.enterText(find.byType(TextField).at(1), '٨٢');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await frames(tester);
    expect(find.textContaining('128/82'), findsOneWidget);
    expect((await repo.load()).bpReadings.single.systolic, 128);
  });

  testWidgets('تأكيد البريد لا يُعرض كدخول مكتمل', (tester) async {
    final auth = _ScriptedAuth(
      const PatientAuthResult(
        PatientAuthStatus.confirmationPending,
        patientConfirmationPendingMessage,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PatientAuthPage(auth: auth, onSignedIn: () {}),
      ),
    );
    await tester.tap(find.text('حساب جديد'));
    await frames(tester);
    await tester.enterText(find.byType(TextField).at(0), 'patient@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret-pass');
    await tester.enterText(find.byType(TextField).at(2), 'secret-pass');
    await tester.tap(find.text('إنشاء الحساب'));
    await frames(tester);
    expect(find.textContaining('لم نتحقق'), findsOneWidget);
    expect(find.textContaining('تم الدخول'), findsNothing);
  });

  testWidgets('المرفق يفتح عارضاً بعد الخروج والعودة', (tester) async {
    final repo = MemoryPatientHealthRepository('user-a', PatientFileDatabase());
    await repo.saveConsent(displayName: 'أحمد', at: now);
    final condition = await repo.saveCondition(
      PatientCondition(
        id: 'cond-a',
        userId: 'user-a',
        kind: ConditionKind.hypertension,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final file = await repo.addAttachment(
      conditionId: condition.id,
      fileName: 'lab.jpg',
      bytes: _tinyPng,
      contentType: 'image/jpeg',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PatientHealthPage(
          repository: repo,
          now: () => now,
          onSignOut: () async {},
          onDeleteAccount: () async {},
        ),
      ),
    );
    await frames(tester);
    expect(find.byKey(Key('attachment-tile-${file.id}')), findsOneWidget);
    await tester.tap(find.byKey(Key('attachment-tile-${file.id}')));
    await frames(tester);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('جاري فتح الصورة...'), findsNothing);
    await tester.pageBack();
    await frames(tester);
    await tester.tap(find.byKey(Key('attachment-tile-${file.id}')));
    await frames(tester);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('تضمين الصور اختياري ولا يُضاف تلقائياً', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final repo = MemoryPatientHealthRepository('user-a', PatientFileDatabase());
    await repo.saveConsent(displayName: 'أحمد', at: now);
    final condition = await repo.saveCondition(
      PatientCondition(
        id: 'cond-a',
        userId: 'user-a',
        kind: ConditionKind.hypertension,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final file = await repo.addAttachment(
      conditionId: condition.id,
      fileName: 'lab.jpg',
      bytes: _tinyPng,
      contentType: 'image/jpeg',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FollowUpCardPage(
          userId: 'user-a',
          snapshot: await repo.load(),
          repository: repo,
          store: AttachmentByteStore(),
          now: () => now,
        ),
      ),
    );
    await frames(tester);
    expect(find.byKey(Key('select-attachment-${file.id}')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('include-attachments')));
    await tester.tap(find.byKey(const Key('include-attachments')));
    await frames(tester);
    expect(find.byKey(Key('select-attachment-${file.id}')), findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(
        find.byKey(Key('select-attachment-${file.id}')),
      ).value,
      isFalse,
    );
  });

  test('تصدير PDF يضيف صفحات الصور المختارة فقط', () async {
    final pdf = await followUpExportPdf(
      cardPng: _tinyPng,
      images: [_tinyPng],
    );
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    expect('/Count 2'.allMatches(String.fromCharCodes(pdf)).isNotEmpty, isTrue);
    final skipped = await followUpExportPdf(cardPng: _tinyPng);
    expect('/Count 1'.allMatches(String.fromCharCodes(skipped)).isNotEmpty, isTrue);
  });

  test('فشل تحميل صورة مختارة يظهر قبل التصدير', () async {
    final selected = [
      HealthAttachment(
        id: 'ok',
        userId: 'user-a',
        conditionId: 'cond-a',
        storagePath: 'user-a/ok',
        fileName: 'ok.jpg',
        createdAt: now,
      ),
      HealthAttachment(
        id: 'bad',
        userId: 'user-a',
        conditionId: 'cond-a',
        storagePath: 'user-a/bad',
        fileName: 'bad.jpg',
        createdAt: now,
      ),
    ];
    await expectLater(
      loadAttachmentsForExport(
        selected: selected,
        load: (id) async {
          if (id == 'bad') throw const PatientAccessDenied();
          return _tinyPng;
        },
      ),
      throwsA(
        isA<AttachmentExportFailure>().having(
          (error) => error.names,
          'names',
          ['bad.jpg'],
        ),
      ),
    );
  });
}

class _ScriptedAuth implements PatientAuthApi {
  _ScriptedAuth(this.result);

  final PatientAuthResult result;

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<PatientAuthResult> requestPasswordReset({required String email}) async {
    return result;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<PatientAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    return result;
  }

  @override
  Future<PatientAuthResult> signUp({
    required String email,
    required String password,
  }) async {
    return result;
  }

  @override
  Future<PatientAuthResult> updatePassword({required String password}) async {
    return result;
  }
}
