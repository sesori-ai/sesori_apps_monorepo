import "dart:async";

import "package:meta/meta.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/platform/notification_open_request.dart";
import "package:sesori_dart_core/src/platform/push_messaging_source.dart";
import "package:sesori_dart_core/src/platform/push_notification_message.dart";
import "package:sesori_dart_core/src/repositories/notification_repository.dart";
import "package:sesori_dart_core/src/services/notification_registration_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("NotificationRegistrationService", () {
    late RecordingNotificationRepository repository;
    late FakeAuthSession authSession;
    late FakePushMessagingSource pushMessagingSource;
    late NotificationRegistrationService service;
    late List<String> operations;

    setUp(() {
      operations = <String>[];
      repository = RecordingNotificationRepository(operations: operations);
      authSession = FakeAuthSession(initialState: _authenticatedState());
      pushMessagingSource = FakePushMessagingSource(
        initialToken: "token-1",
        devicePlatform: DevicePlatform.android,
        operations: operations,
      );
      service = NotificationRegistrationService(
        repository: repository,
        authSession: authSession,
        pushMessagingSource: pushMessagingSource,
      );
    });

    tearDown(() async {
      await service.dispose();
      await authSession.dispose();
      await pushMessagingSource.dispose();
    });

    test("auth state and token refresh keep server and local registration in sync", () async {
      await service.start();

      expect(
        repository.registeredTokens,
        equals([
          const RegisteredToken(token: "token-1", platform: DevicePlatform.android),
        ]),
      );
      expect(repository.unregisteredTokens, isEmpty);

      pushMessagingSource.emitTokenRefresh("token-2");
      await Future<void>.delayed(Duration.zero);

      expect(
        repository.unregisteredTokens,
        equals(["token-1"]),
      );
      expect(
        repository.registeredTokens,
        equals([
          const RegisteredToken(token: "token-1", platform: DevicePlatform.android),
          const RegisteredToken(token: "token-2", platform: DevicePlatform.android),
        ]),
      );

      authSession.emit(const AuthState.unauthenticated());
      await Future<void>.delayed(Duration.zero);

      expect(repository.unregisteredTokens, equals(["token-1"]));
      expect(pushMessagingSource.deleteTokenCalls, 1);
      expect(pushMessagingSource.currentToken, isNull);
    });

    test("unauthenticated refresh is deleted until auth returns", () async {
      authSession.emit(const AuthState.unauthenticated());
      await service.start();
      await Future<void>.delayed(Duration.zero);

      expect(repository.registeredTokens, isEmpty);
      expect(pushMessagingSource.deleteTokenCalls, 1);

      pushMessagingSource.currentToken = "token-2";
      pushMessagingSource.emitTokenRefresh("token-2");
      await Future<void>.delayed(Duration.zero);

      expect(repository.registeredTokens, isEmpty);
      expect(pushMessagingSource.deleteTokenCalls, 2);
      expect(pushMessagingSource.currentToken, isNull);

      pushMessagingSource.currentToken = "token-3";
      authSession.emit(_authenticatedState());
      await Future<void>.delayed(Duration.zero);

      expect(
        repository.registeredTokens,
        equals([
          const RegisteredToken(token: "token-3", platform: DevicePlatform.android),
        ]),
      );
    });

    test("unauthenticated startup deletes the current local token after restart", () async {
      authSession = FakeAuthSession(initialState: const AuthState.unauthenticated());
      pushMessagingSource = FakePushMessagingSource(
        initialToken: "token-1",
        devicePlatform: DevicePlatform.android,
        operations: operations,
      );
      service = NotificationRegistrationService(
        repository: repository,
        authSession: authSession,
        pushMessagingSource: pushMessagingSource,
      );

      await service.start();

      expect(repository.registeredTokens, isEmpty);
      expect(repository.unregisteredTokens, isEmpty);
      expect(pushMessagingSource.deleteTokenCalls, 1);
      expect(pushMessagingSource.currentToken, isNull);
    });

    test("logout cleanup unregisters remotely before auth deletes the local token", () async {
      await service.start();
      operations.clear();

      await service.unregisterCurrentDevice();

      expect(operations, equals(["unregister:token-1"]));
      expect(repository.unregisteredTokens, equals(["token-1"]));
      expect(pushMessagingSource.deleteTokenCalls, 0);

      pushMessagingSource.emitTokenRefresh("token-2");
      await Future<void>.delayed(Duration.zero);

      expect(
        repository.registeredTokens,
        equals([
          const RegisteredToken(token: "token-1", platform: DevicePlatform.android),
        ]),
      );
      expect(pushMessagingSource.deleteTokenCalls, 0);

      authSession.emit(const AuthState.unauthenticated());
      await Future<void>.delayed(Duration.zero);

      expect(operations, equals(["unregister:token-1", "delete-local"]));
      expect(pushMessagingSource.deleteTokenCalls, 1);
    });

    test("unauthenticated cleanup retries local deletion after failures", () async {
      await service.start();
      repository.failNextUnregisterToken = true;
      pushMessagingSource.failNextDeleteToken = true;

      await service.unregisterCurrentDevice();

      expect(repository.unregisteredTokens, equals(["token-1"]));
      expect(pushMessagingSource.deleteTokenCalls, 0);

      authSession.emit(const AuthState.unauthenticated());
      await Future<void>.delayed(Duration.zero);

      expect(pushMessagingSource.deleteTokenCalls, 1);

      pushMessagingSource.emitTokenRefresh("token-2");
      await Future<void>.delayed(Duration.zero);

      expect(pushMessagingSource.deleteTokenCalls, 2);
      expect(pushMessagingSource.currentToken, isNull);
    });

    test("queued authenticated work cannot clear logout suspension", () async {
      await service.start();
      final tokenCompleter = Completer<String?>();
      pushMessagingSource.tokenFuture = tokenCompleter.future;

      authSession.emit(_authenticatedState());
      await Future<void>.delayed(Duration.zero);
      final cleanupFuture = service.unregisterCurrentDevice();
      pushMessagingSource.emitTokenRefresh("token-2");

      tokenCompleter.complete("token-1");
      await cleanupFuture;
      await Future<void>.delayed(Duration.zero);

      expect(
        repository.registeredTokens,
        equals([
          const RegisteredToken(token: "token-1", platform: DevicePlatform.android),
        ]),
      );
      expect(repository.unregisteredTokens, equals(["token-1"]));
    });

    test("keeps listening after an initial sync failure", () async {
      repository.failNextRegisterToken = true;

      await service.start();

      expect(repository.registeredTokens, isEmpty);

      authSession.emit(const AuthState.unauthenticated());
      await Future<void>.delayed(Duration.zero);
      pushMessagingSource.currentToken = "token-1";
      authSession.emit(_authenticatedState());
      await Future<void>.delayed(Duration.zero);

      expect(
        repository.registeredTokens,
        equals([
          const RegisteredToken(token: "token-1", platform: DevicePlatform.android),
        ]),
      );

      pushMessagingSource.emitTokenRefresh("token-2");
      await Future<void>.delayed(Duration.zero);

      expect(repository.unregisteredTokens, equals(["token-1"]));
      expect(
        repository.registeredTokens,
        equals([
          const RegisteredToken(token: "token-1", platform: DevicePlatform.android),
          const RegisteredToken(token: "token-2", platform: DevicePlatform.android),
        ]),
      );
    });

    test("processes auth changes that happen during the initial sync window", () async {
      final tokenCompleter = Completer<String?>();
      pushMessagingSource.tokenFuture = tokenCompleter.future;

      final startFuture = service.start();
      authSession.emit(const AuthState.unauthenticated());

      tokenCompleter.complete("token-1");
      await startFuture;
      await Future<void>.delayed(Duration.zero);

      expect(
        repository.registeredTokens,
        equals([
          const RegisteredToken(token: "token-1", platform: DevicePlatform.android),
        ]),
      );
      expect(repository.unregisteredTokens, isEmpty);
      expect(pushMessagingSource.deleteTokenCalls, 1);
    });

    test("processes the first changed auth snapshot after startup sync", () async {
      final tokenCompleter = Completer<String?>();
      pushMessagingSource.tokenFuture = tokenCompleter.future;

      final startFuture = service.start();
      authSession.emit(const AuthState.unauthenticated());
      authSession.emit(_authenticatedState());

      tokenCompleter.complete("token-1");
      await startFuture;
      await Future<void>.delayed(Duration.zero);

      expect(
        repository.registeredTokens,
        equals([
          const RegisteredToken(token: "token-1", platform: DevicePlatform.android),
          const RegisteredToken(token: "token-1", platform: DevicePlatform.android),
        ]),
      );
      expect(repository.unregisteredTokens, isEmpty);
      expect(pushMessagingSource.deleteTokenCalls, 1);
    });
  });
}

class RecordingNotificationRepository implements NotificationRepository {
  final List<RegisteredToken> registeredTokens = <RegisteredToken>[];
  final List<String> unregisteredTokens = <String>[];
  final List<String> operations;
  bool failNextRegisterToken = false;
  bool failNextUnregisterToken = false;

  RecordingNotificationRepository({required this.operations});

  @override
  Future<void> registerToken({required String token, required DevicePlatform platform}) async {
    if (failNextRegisterToken) {
      failNextRegisterToken = false;
      throw StateError("register token failed");
    }
    registeredTokens.add(RegisteredToken(token: token, platform: platform));
    operations.add("register:$token");
  }

  @override
  Future<void> unregisterToken({required String token}) async {
    unregisteredTokens.add(token);
    operations.add("unregister:$token");
    if (failNextUnregisterToken) {
      failNextUnregisterToken = false;
      throw StateError("unregister token failed");
    }
  }
}

@immutable
class RegisteredToken {
  final String token;
  final DevicePlatform platform;

  const RegisteredToken({required this.token, required this.platform});

  @override
  bool operator ==(Object other) {
    return other is RegisteredToken && other.token == token && other.platform == platform;
  }

  @override
  int get hashCode => Object.hash(token, platform);
}

class FakeAuthSession implements AuthSession {
  final BehaviorSubject<AuthState> _authStates;

  FakeAuthSession({required AuthState initialState}) : _authStates = BehaviorSubject<AuthState>.seeded(initialState);

  @override
  ValueStream<AuthState> get authStateStream => _authStates.stream;

  @override
  AuthState get currentState => _authStates.value;

  void emit(AuthState state) => _authStates.add(state);

  Future<void> dispose() async => _authStates.close();

  @override
  Future<AuthUser?> getCurrentUser() async => null;

  @override
  Future<bool> hasLocallyValidSession() async => false;

  @override
  Future<void> invalidateAllSessions() async {}

  @override
  Future<void> logoutCurrentDevice() async {}

  @override
  Future<bool> restoreSession() async => false;

  @override
  Future<bool> restoreLocalSession() async => false;

  @override
  Future<AuthUser> loginWithEmail({required String email, required String password}) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser> loginWithApple({required String idToken, required String nonce}) async {
    throw UnimplementedError();
  }
}

class FakePushMessagingSource implements PushMessagingSource {
  final StreamController<String> _tokenRefreshController = StreamController<String>.broadcast();
  final StreamController<PushNotificationMessage> _foregroundMessageController =
      StreamController<PushNotificationMessage>.broadcast();
  final StreamController<NotificationOpenRequest> _notificationOpenedController =
      StreamController<NotificationOpenRequest>.broadcast();

  @override
  final DevicePlatform devicePlatform;
  final List<String> operations;

  String? currentToken;
  Future<String?>? tokenFuture;
  int deleteTokenCalls = 0;
  bool failNextDeleteToken = false;

  FakePushMessagingSource({
    required String? initialToken,
    required this.devicePlatform,
    required this.operations,
  }) : currentToken = initialToken;

  @override
  Stream<PushNotificationMessage> get foregroundMessageStream => _foregroundMessageController.stream;

  @override
  Future<NotificationOpenRequest?> getInitialNotificationOpen() async => null;

  @override
  Future<String?> getToken() async => tokenFuture ?? currentToken;

  @override
  Future<void> deleteToken() async {
    deleteTokenCalls++;
    operations.add("delete-local");
    if (failNextDeleteToken) {
      failNextDeleteToken = false;
      throw StateError("delete token failed");
    }
    currentToken = null;
  }

  @override
  Future<void> initialize() async {}

  @override
  Stream<NotificationOpenRequest> get notificationOpenedStream => _notificationOpenedController.stream;

  @override
  Stream<String> get tokenRefreshStream => _tokenRefreshController.stream;

  void emitTokenRefresh(String token) {
    currentToken = token;
    _tokenRefreshController.add(token);
  }

  Future<void> dispose() async {
    await _tokenRefreshController.close();
    await _foregroundMessageController.close();
    await _notificationOpenedController.close();
  }
}

AuthState _authenticatedState() {
  return const AuthState.authenticated(
    user: AuthUser(
      id: "user-1",
      provider: AuthProvider.github,
      providerUserId: "provider-user-1",
      providerUsername: "alex",
    ),
  );
}
