import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import 'firebase_options.dart';
import 'sensitive_data_store.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  final bool firebaseReady =
      await RemoteDeleteFcmService.ensureFirebaseInitialized();

  if (!firebaseReady) {
    return;
  }

  await RemoteDeleteFcmService.handleRemoteMessage(
    message,
    store: SensitiveDataStore.instance,
    source: 'background',
  );
}

class RemoteDeleteFcmService {
  RemoteDeleteFcmService._({SensitiveDataRepository? store})
    : _store = store ?? SensitiveDataStore.instance;

  static final RemoteDeleteFcmService instance = RemoteDeleteFcmService._();

  static const String remoteDeleteAction = 'remote_delete_sensitive_data';
  static const String userScope = 'user';

  final SensitiveDataRepository _store;
  final ValueNotifier<RemoteDeleteResult?> lastRemoteDelete =
      ValueNotifier<RemoteDeleteResult?>(null);

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;
  bool _firebaseReady = false;

  bool get firebaseReady => _firebaseReady;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    _firebaseReady = await ensureFirebaseInitialized();

    if (!_firebaseReady) {
      debugPrint(
        'Firebase no esta configurado; FCM remoto queda deshabilitado.',
      );
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await _cacheCurrentToken();

    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
        .listen(_store.saveFcmToken);

    _foregroundSubscription = FirebaseMessaging.onMessage.listen((
      RemoteMessage message,
    ) {
      _processRemoteMessage(message, source: 'foreground');
    });

    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      RemoteMessage message,
    ) {
      _processRemoteMessage(message, source: 'opened_app');
    });

    final RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();

    if (initialMessage != null) {
      await _processRemoteMessage(initialMessage, source: 'initial_message');
    }
  }

  Future<void> bindCurrentUser(String userId) async {
    if (!_firebaseReady) {
      return;
    }

    await _cacheCurrentToken();
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    lastRemoteDelete.dispose();
  }

  static Future<bool> ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) {
      return true;
    }

    final FirebaseOptions options = DefaultFirebaseOptions.currentPlatform;

    if (!_optionsLookConfigured(options)) {
      return false;
    }

    try {
      await Firebase.initializeApp(options: options);
      return true;
    } catch (error) {
      debugPrint('No se pudo inicializar Firebase: $error');
      return false;
    }
  }

  static Future<RemoteDeleteResult?> handleRemoteMessage(
    RemoteMessage message, {
    required SensitiveDataRepository store,
    required String source,
  }) async {
    final RemoteDeleteCommand? command = RemoteDeleteCommand.fromMessage(
      message,
    );

    if (command == null) {
      return null;
    }

    final RemoteDeleteResult result = await store.deleteSensitiveDataForTarget(
      targetUserId: command.targetUserId,
      reason: command.reason,
      source: source,
    );

    debugPrint(result.message);
    return result;
  }

  Future<void> _cacheCurrentToken() async {
    final String? token = await FirebaseMessaging.instance.getToken();

    if (token != null && token.isNotEmpty) {
      await _store.saveFcmToken(token);
    }
  }

  Future<void> _processRemoteMessage(
    RemoteMessage message, {
    required String source,
  }) async {
    final RemoteDeleteResult? result = await handleRemoteMessage(
      message,
      store: _store,
      source: source,
    );

    if (result != null && result.applied) {
      lastRemoteDelete.value = result;
    }
  }

  static bool _optionsLookConfigured(FirebaseOptions options) {
    final List<String> requiredValues = <String>[
      options.apiKey,
      options.appId,
      options.messagingSenderId,
      options.projectId,
    ];

    return requiredValues.every((String value) => value.isNotEmpty);
  }
}

class RemoteDeleteCommand {
  const RemoteDeleteCommand({required this.targetUserId, this.reason});

  final String targetUserId;
  final String? reason;

  static RemoteDeleteCommand? fromMessage(RemoteMessage message) {
    final Map<String, dynamic> data = message.data;
    final String action = _readString(data, <String>['action', 'type']);
    final String scope = _readString(data, <String>['scope']);
    final String targetUserId = _readString(data, <String>[
      'targetUserId',
      'userId',
      'uid',
    ]);
    final String reason = _readString(data, <String>['reason']);

    if (action != RemoteDeleteFcmService.remoteDeleteAction) {
      return null;
    }

    if (scope != RemoteDeleteFcmService.userScope || targetUserId.isEmpty) {
      debugPrint('Borrado remoto ignorado: falta scope=user o targetUserId.');
      return null;
    }

    return RemoteDeleteCommand(
      targetUserId: targetUserId,
      reason: reason.isEmpty ? null : reason,
    );
  }

  static String _readString(Map<String, dynamic> data, List<String> keys) {
    for (final String key in keys) {
      final Object? value = data[key];

      if (value != null) {
        return value.toString().trim();
      }
    }

    return '';
  }
}
