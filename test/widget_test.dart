import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safelogin/main.dart';
import 'package:safelogin/sensitive_data_store.dart';

void main() {
  testWidgets('Home counter increments when button is pressed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(usuario: 'admin', storage: _FakeSensitiveDataStore()),
      ),
    );

    expect(find.text('Haz pulsado este boton 0 veces'), findsOneWidget);
    expect(find.text('Haz pulsado este boton 1 veces'), findsNothing);

    await tester.tap(find.text('Pulsar boton'));
    await tester.pump();

    expect(find.text('Haz pulsado este boton 0 veces'), findsNothing);
    expect(find.text('Haz pulsado este boton 1 veces'), findsOneWidget);
  });
}

class _FakeSensitiveDataStore implements SensitiveDataRepository {
  @override
  Future<RemoteDeleteResult> deleteSensitiveDataForTarget({
    required String targetUserId,
    String? reason,
    String? source,
  }) async {
    return RemoteDeleteResult(
      applied: true,
      message: 'ok',
      targetUserId: targetUserId,
      deletedAt: DateTime.utc(2026, 6, 8),
    );
  }

  @override
  Future<String?> readFcmToken() async => 'fake-fcm-token';

  @override
  Future<String?> readLastRemoteDeleteAt() async => null;

  @override
  Future<String?> readRegisteredUserId() async => 'admin';

  @override
  Future<SensitiveDataSnapshot> readSensitiveData() async {
    return const SensitiveDataSnapshot(<String, String?>{
      'sensitive.session_token': 'session_1234',
      'sensitive.refresh_token': 'refresh_1234',
      'sensitive.account_number': 'MX1234567890',
      'sensitive.security_pin': '123456',
    });
  }

  @override
  Future<void> saveFcmToken(String token) async {}

  @override
  Future<void> seedForUser(String userId) async {}
}
