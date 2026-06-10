import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SensitiveFieldDefinition {
  const SensitiveFieldDefinition({required this.key, required this.label});

  final String key;
  final String label;
}

class SensitiveDataSnapshot {
  const SensitiveDataSnapshot(this.values);

  final Map<String, String?> values;

  bool get hasAnyValue {
    return values.values.any(
      (String? value) => value != null && value.isNotEmpty,
    );
  }

  String? valueFor(String key) => values[key];
}

class RemoteDeleteResult {
  const RemoteDeleteResult({
    required this.applied,
    required this.message,
    this.targetUserId,
    this.deletedAt,
  });

  final bool applied;
  final String message;
  final String? targetUserId;
  final DateTime? deletedAt;
}

abstract class SensitiveDataRepository {
  Future<void> seedForUser(String userId);

  Future<SensitiveDataSnapshot> readSensitiveData();

  Future<String?> readRegisteredUserId();

  Future<void> saveFcmToken(String token);

  Future<String?> readFcmToken();

  Future<String?> readLastRemoteDeleteAt();

  Future<RemoteDeleteResult> deleteSensitiveDataForTarget({
    required String targetUserId,
    String? reason,
    String? source,
  });
}

class SensitiveDataStore implements SensitiveDataRepository {
  SensitiveDataStore._();

  static final SensitiveDataStore instance = SensitiveDataStore._();

  static const List<SensitiveFieldDefinition>
  sensitiveFields = <SensitiveFieldDefinition>[
    SensitiveFieldDefinition(key: _sessionTokenKey, label: 'Token de sesion'),
    SensitiveFieldDefinition(
      key: _refreshTokenKey,
      label: 'Token de renovacion',
    ),
    SensitiveFieldDefinition(key: _accountNumberKey, label: 'Cuenta bancaria'),
    SensitiveFieldDefinition(key: _securityPinKey, label: 'PIN de seguridad'),
  ];

  static const String _sessionTokenKey = 'sensitive.session_token';
  static const String _refreshTokenKey = 'sensitive.refresh_token';
  static const String _accountNumberKey = 'sensitive.account_number';
  static const String _securityPinKey = 'sensitive.security_pin';
  static const String _registeredUserKey = 'profile.registered_user_id';
  static const String _fcmTokenKey = 'profile.fcm_token';
  static const String _lastRemoteDeleteAtKey = 'audit.last_remote_delete_at';
  static const String _lastRemoteDeleteReasonKey =
      'audit.last_remote_delete_reason';
  static const String _lastRemoteDeleteSourceKey =
      'audit.last_remote_delete_source';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(storageNamespace: 'safelogin_secure_vault'),
    iOptions: IOSOptions(
      accountName: 'safelogin_secure_vault',
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final Random _random = Random.secure();

  @override
  Future<void> seedForUser(String userId) async {
    final String cleanUserId = userId.trim();
    final Map<String, String> generatedValues = _generateSensitiveValues(
      cleanUserId,
    );

    await _storage.write(key: _registeredUserKey, value: cleanUserId);

    for (final SensitiveFieldDefinition field in sensitiveFields) {
      final String? currentValue = await _storage.read(key: field.key);

      if (currentValue == null || currentValue.isEmpty) {
        await _storage.write(key: field.key, value: generatedValues[field.key]);
      }
    }
  }

  @override
  Future<SensitiveDataSnapshot> readSensitiveData() async {
    final Map<String, String?> values = <String, String?>{};

    for (final SensitiveFieldDefinition field in sensitiveFields) {
      values[field.key] = await _storage.read(key: field.key);
    }

    return SensitiveDataSnapshot(values);
  }

  @override
  Future<String?> readRegisteredUserId() {
    return _storage.read(key: _registeredUserKey);
  }

  @override
  Future<void> saveFcmToken(String token) {
    return _storage.write(key: _fcmTokenKey, value: token);
  }

  @override
  Future<String?> readFcmToken() {
    return _storage.read(key: _fcmTokenKey);
  }

  @override
  Future<String?> readLastRemoteDeleteAt() {
    return _storage.read(key: _lastRemoteDeleteAtKey);
  }

  @override
  Future<RemoteDeleteResult> deleteSensitiveDataForTarget({
    required String targetUserId,
    String? reason,
    String? source,
  }) async {
    final String? registeredUserId = await readRegisteredUserId();
    final String cleanTargetUserId = targetUserId.trim();

    if (registeredUserId == null || registeredUserId != cleanTargetUserId) {
      return RemoteDeleteResult(
        applied: false,
        message: 'Usuario destino no coincide con este dispositivo.',
        targetUserId: cleanTargetUserId,
      );
    }

    for (final SensitiveFieldDefinition field in sensitiveFields) {
      await _storage.delete(key: field.key);
    }

    final DateTime deletedAt = DateTime.now().toUtc();
    await _storage.write(
      key: _lastRemoteDeleteAtKey,
      value: deletedAt.toIso8601String(),
    );
    await _storage.write(
      key: _lastRemoteDeleteReasonKey,
      value: reason ?? 'remote_delete_sensitive_data',
    );
    await _storage.write(
      key: _lastRemoteDeleteSourceKey,
      value: source ?? 'fcm',
    );

    return RemoteDeleteResult(
      applied: true,
      message: 'Datos sensibles eliminados por solicitud remota.',
      targetUserId: cleanTargetUserId,
      deletedAt: deletedAt,
    );
  }

  Map<String, String> _generateSensitiveValues(String userId) {
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final String nonce = _randomToken(18);

    return <String, String>{
      _sessionTokenKey: 'sess_${userId}_${timestamp}_$nonce',
      _refreshTokenKey: 'refresh_${userId}_${timestamp}_${_randomToken(18)}',
      _accountNumberKey: 'MX${_randomDigits(18)}',
      _securityPinKey: _randomDigits(6),
    };
  }

  String _randomDigits(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(10)).join();
  }

  String _randomToken(int length) {
    const String alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

    return List<String>.generate(
      length,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }
}
