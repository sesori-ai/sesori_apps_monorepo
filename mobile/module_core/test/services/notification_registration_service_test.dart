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

    setUp(() {
      repository = RecordingNotificationRepository();
      authSession = FakeAuthSession(initialState: _authenticatedState());
      pushMessagingSource = FakePushMessagingSource(
        initialToken: "token-1",
        devicePlatform: DevicePlatform.android,
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

    test("auth state and token refresh drive registration pipeline only", () async {
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

      expect(repository.unregisteredTokens, equals(["token-1", "token-2"]));
    });

    test("unauthenticated refresh does not register until auth returns", () async {
      authSession.emit(const AuthState.unauthenticated());
      await service.start();
      await Future<void>.delayed(Duration.zero);

      expect(repository.registeredTokens, isEmpty);

      pushMessagingSource.currentToken = "token-2";
      pushMessagingSource.emitTokenRefresh("token-2");
      await Future<void>.delayed(Duration.zero);

      expect(repository.registeredTokens, isEmpty);

      authSession.emit(_authenticatedState());
      await Future<void>.delayed(Duration.zero);

      expect(
        repository.registeredTokens,
        equals([
          const RegisteredToken(token: "token-2", platform: DevicePlatform.android),
        ]),
      );
    });

    test("unauthenticated startup unregisters the current device token after restart", () async {
      authSession = FakeAuthSession(initialState: const AuthState.unauthenticated());
      pushMessagingSource = FakePushMessagingSource(
        initialToken: "token-1",
        devicePlatform: DevicePlatform.android,
      );
      service = NotificationRegistrationService(
        repository: repository,
        authSession: authSession,
        pushMessagingSource: pushMessagingSource,
      );

      await service.start();

      expect(repository.registeredTokens, isEmpty);
      expect(repository.unregisteredTokens, equals(["token-1"]));
    });

    test("keeps listening after an initial sync failure", () async {
      repository.failNextRegisterToken = true;

      await service.start();

      expect(repository.registeredTokens, isEmpty);

      authSession.emit(const AuthState.unauthenticated());
      await Future<void>.delayed(Duration.zero);
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

      expect(repository.unregisteredTokens, equals(["token-1", "token-1"]));
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
      expect(repository.unregisteredTokens, equals(["token-1"]));
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
      expect(repository.unregisteredTokens, equals(["token-1"]));
    });
  });
}

class RecordingNotificationRepository implements NotificationRepository {
  final List<RegisteredToken> registeredTokens = <RegisteredToken>[];
  final List<String> unregisteredTokens = <String>[];
  bool failNextRegisterToken = false;

  @override
  Future<void> registerToken({required String token, required DevicePlatform platform}) async {
    if (failNextRegisterToken) {
      failNextRegisterToken = false;
      throw StateError("register token failed");
    }
    registeredTokens.add(RegisteredToken(token: token, platform: platform));
  }

  @override
  Future<void> unregisterToken({required String token}) async {
    unregisteredTokens.add(token);
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
  Future<void> invalidateAllSessions() async {}

  @override
  Future<void> logoutCurrentDevice() async {}

  @override
  Future<bool> restoreSession() async => false;

  @override
  Future<AuthUser> loginWithEmail({required String email, required String password}) async {
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

  String? currentToken;
  Future<String?>? tokenFuture;

  FakePushMessagingSource({required String? initialToken, required this.devicePlatform}) : currentToken = initialToken;

  @override
  Stream<PushNotificationMessage> get foregroundMessageStream => _foregroundMessageController.stream;

  @override
  Future<NotificationOpenRequest?> getInitialNotificationOpen() async => null;

  @override
  Future<String?> getToken() async => tokenFuture ?? currentToken;

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
      provider: "github",
      providerUserId: "provider-user-1",
      providerUsername: "alex",
    ),
  );
}
