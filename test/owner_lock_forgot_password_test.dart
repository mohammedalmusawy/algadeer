import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghadeer_clinic/doctors/doctor_card_access_client.dart';
import 'package:ghadeer_clinic/doctors/doctor_card_gate.dart';

/// قفل المالك: «نسيت كلمة السر؟» يفتح واتساب الإدارة برسالة جاهزة،
/// وزر إصدار رمز جديد يظهر للإدارة فقط.
class _FakeClient extends DoctorCardAccessClient {
  _FakeClient({this.mode = 'password'});

  final String mode;
  int resets = 0;
  int? lastTtl;

  @override
  Future<EntityOwnerPreview> preview({
    required String entityType,
    required String entityId,
  }) async {
    return EntityOwnerPreview(mode: mode, waitSeconds: 0);
  }

  @override
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
    if (reset) resets++;
    lastTtl = codeTtlMinutes;
    return const EntityOwnerAdminState(
      mode: 'activate',
      permissions: ['bio'],
      activationCode: '482913',
      isActive: true,
      displayOrder: 0,
    );
  }
}

Future<void> _open(
  WidgetTester tester, {
  required _FakeClient client,
  required bool admin,
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showEntityOwnerSession(
                context,
                entityType: 'pharmacy',
                entityId: 'ph-1',
                title: 'صيدلية الرحاب',
                client: client,
                adminSignedIn: () => admin,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  test('رسالة نسيت كلمة السر تروح لواتساب الغدير وبيها اسم البطاقة', () {
    final uri = ownerForgotPasswordUri('صيدلية الرحاب')!;
    expect(uri.host, 'wa.me');
    expect(uri.path, '/9647822202288');
    final text = uri.queryParameters['text']!;
    expect(text, contains('صيدلية الرحاب'));
    expect(text, contains('نسيت كلمة سر'));
  });

  testWidgets('المالك يشوف «نسيت كلمة السر؟» وما يشوف زر الإدارة', (
    tester,
  ) async {
    await _open(tester, client: _FakeClient(), admin: false);
    expect(find.byKey(const Key('owner-forgot-password')), findsOneWidget);
    expect(find.byKey(const Key('owner-admin-issue-code')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('الإدارة تصدر رمز جديد من القفل نفسه وتختار مدته', (
    tester,
  ) async {
    final client = _FakeClient();
    await _open(tester, client: client, admin: true);
    final button = find.byKey(const Key('owner-admin-issue-code'));
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    // الإدارة تختار المدة أولاً: نص ساعة / ساعتين / يوم.
    expect(find.byKey(const Key('owner-code-ttl-120')), findsOneWidget);
    await tester.tap(find.byKey(const Key('owner-code-ttl-30')));
    await tester.pumpAndSettle();
    expect(client.resets, 1);
    expect(client.lastTtl, 30);
    expect(find.byKey(const Key('owner-admin-code')), findsOneWidget);
    expect(find.textContaining('نص ساعة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('بطاقة غير مفعّلة: لا نسيت كلمة السر ولا زر إدارة', (
    tester,
  ) async {
    await _open(tester, client: _FakeClient(mode: 'disabled'), admin: true);
    expect(find.byKey(const Key('owner-forgot-password')), findsNothing);
    expect(find.byKey(const Key('owner-admin-issue-code')), findsNothing);
  });
}
