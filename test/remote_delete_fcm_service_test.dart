import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safelogin/remote_delete_fcm_service.dart';
import 'package:safelogin/sensitive_data_store.dart';

void main() {
  test('ignores general remote delete messages without user scope', () async {
    final _RecordingSensitiveDataStore store = _RecordingSensitiveDataStore(
      registeredUserId: 'admin',
    );

    final RemoteDeleteResult? result =
        await RemoteDeleteFcmService.handleRemoteMessage(
          const RemoteMessage(
            data: <String, dynamic>{
              'action': RemoteDeleteFcmService.remoteDeleteAction,
            },
          ),
          store: store,
          source: 'test',
        );

    expect(result, isNull);
    expect(store.deleteCalls, 0);
  });

  test('deletes sensitive data for the matching target user', () async {
    final _RecordingSensitiveDataStore store = _RecordingSensitiveDataStore(
      registeredUserId: 'admin',
    );

    final RemoteDeleteResult? result =
        await RemoteDeleteFcmService.handleRemoteMessage(
          const RemoteMessage(
            data: <String, dynamic>{
              'action': RemoteDeleteFcmService.remoteDeleteAction,
              'scope': RemoteDeleteFcmService.userScope,
              'targetUserId': 'admin',
            },
          ),
          store: store,
          source: 'test',
        );

    expect(result?.applied, isTrue);
    expect(store.deleteCalls, 1);
  });

  test('does not delete sensitive data for a different target user', () async {
    final _RecordingSensitiveDataStore store = _RecordingSensitiveDataStore(
      registeredUserId: 'admin',
    );

    final RemoteDeleteResult? result =
        await RemoteDeleteFcmService.handleRemoteMessage(
          const RemoteMessage(
            data: <String, dynamic>{
              'action': RemoteDeleteFcmService.remoteDeleteAction,
              'scope': RemoteDeleteFcmService.userScope,
              'targetUserId': 'other-user',
            },
          ),
          store: store,
          source: 'test',
        );

    expect(result?.applied, isFalse);
    expect(store.deleteCalls, 1);
    expect(store.deleted, isFalse);
  });
}

class _RecordingSensitiveDataStore implements SensitiveDataRepository {
  _RecordingSensitiveDataStore({required this.registeredUserId});

  final String registeredUserId;
  int deleteCalls = 0;
  bool deleted = false;

  @override
  Future<RemoteDeleteResult> deleteSensitiveDataForTarget({
    required String targetUserId,
    String? reason,
    String? source,
  }) async {
    deleteCalls++;

    if (targetUserId != registeredUserId) {
      return RemoteDeleteResult(
        applied: false,
        message: 'ignored',
        targetUserId: targetUserId,
      );
    }

    deleted = true;
    return RemoteDeleteResult(
      applied: true,
      message: 'deleted',
      targetUserId: targetUserId,
      deletedAt: DateTime.utc(2026, 6, 8),
    );
  }

  @override
  Future<String?> readFcmToken() async => null;

  @override
  Future<String?> readLastRemoteDeleteAt() async => null;

  @override
  Future<String?> readRegisteredUserId() async => registeredUserId;

  @override
  Future<SensitiveDataSnapshot> readSensitiveData() async {
    return const SensitiveDataSnapshot(<String, String?>{});
  }

  @override
  Future<void> saveFcmToken(String token) async {}

  @override
  Future<void> seedForUser(String userId) async {}
}
