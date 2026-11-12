import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:meta/meta.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/logging/logging.dart";
import "package:sesori_dart_core/src/platform/notification_open_request.dart";
import "package:sesori_dart_core/src/platform/push_messaging_source.dart";
import "package:sesori_dart_core/src/platform/push_notification_message.dart";
import "package:sesori_dart_core/src/repositories/notification_repository.dart";
import "package:sesori_dart_core/src/services/notification_registration_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

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
        fid: "fid-1",
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

    test("auth state and FID events keep server and local registration in sync", () async {
      await service.start();
      await _settle();

      expect(pushMessagingSource.registerCalls, 1);
      expect(
        repository.registeredFids,
        equals([const RegisteredFid(fid: "fid-1", platform: DevicePlatform.android)]),
      );
      expect(repository.unregisteredFids, isEmpty);

      // A repeated report of the registered FID is not sent again.
      pushMessagingSource.emitRegisteredFid("fid-1");
      await _settle();
      expect(repository.registeredFids, hasLength(1));

      pushMessagingSource.emitRegisteredFid("fid-2");
      await _settle();

      expect(repository.unregisteredFids, equals(["fid-1"]));
      expect(
        repository.registeredFids,
        equals([
          const RegisteredFid(fid: "fid-1", platform: DevicePlatform.android),
          const RegisteredFid(fid: "fid-2", platform: DevicePlatform.android),
        ]),
      );

      authSession.emit(const AuthState.unauthenticated());
      await _settle();

      expect(repository.unregisteredFids, equals(["fid-1"]));
      expect(pushMessagingSource.unregisterCalls, 1);
    });

    test("unauthenticated registrations are undone locally until auth returns", () async {
      authSession.emit(const AuthState.unauthenticated());
      await service.start();
      await _settle();

      expect(repository.registeredFids, isEmpty);
      expect(pushMessagingSource.registerCalls, 0);
      expect(pushMessagingSource.unregisterCalls, 1);

      pushMessagingSource.emitRegisteredFid("fid-2");
      await _settle();

      expect(repository.registeredFids, isEmpty);
      expect(pushMessagingSource.unregisterCalls, 2);

      pushMessagingSource.currentFid = "fid-3";
      authSession.emit(_authenticatedState());
      await _settle();

      expect(
        repository.registeredFids,
        equals([const RegisteredFid(fid: "fid-3", platform: DevicePlatform.android)]),
      );
    });

    test("logout cleanup unregisters remotely before auth unregisters locally", () async {
      await service.start();
      await _settle();
      operations.clear();

      await service.unregisterCurrentDevice();

      expect(operations, equals(["unregister:fid-1"]));
      expect(pushMessagingSource.unregisterCalls, 0);

      pushMessagingSource.emitRegisteredFid("fid-2");
      await _settle();

      expect(
        repository.registeredFids,
        equals([const RegisteredFid(fid: "fid-1", platform: DevicePlatform.android)]),
      );

      authSession.emit(const AuthState.unauthenticated());
      await _settle();

      expect(operations, equals(["unregister:fid-1", "unregister-local"]));
    });

    // The FID is known only from events, so logout must not depend on the
    // server registration having succeeded during this run.
    test("logout removes the reported FID even when its server registration failed", () async {
      repository.failNextRegisterFid = true;
      await service.start();
      await _settle();

      expect(repository.registeredFids, isEmpty);

      await service.unregisterCurrentDevice();

      expect(repository.unregisteredFids, equals(["fid-1"]));
    });

    test("unauthenticated cleanup retries local unregistration after failures", () async {
      await service.start();
      await _settle();
      repository.failNextUnregisterFid = true;
      pushMessagingSource.failNextUnregister = true;

      await service.unregisterCurrentDevice();

      expect(repository.unregisteredFids, equals(["fid-1"]));
      expect(pushMessagingSource.unregisterCalls, 0);

      authSession.emit(const AuthState.unauthenticated());
      await _settle();

      expect(pushMessagingSource.unregisterCalls, 1);

      pushMessagingSource.emitRegisteredFid("fid-2");
      await _settle();

      expect(pushMessagingSource.unregisterCalls, 2);
    });

    test("queued authenticated work cannot clear logout suspension", () async {
      await service.start();
      await _settle();
      final registerGate = Completer<void>();
      pushMessagingSource.registerGate = registerGate.future;

      authSession.emit(_authenticatedState());
      await _settle();
      final cleanupFuture = service.unregisterCurrentDevice();
      pushMessagingSource.emitRegisteredFid("fid-2");

      registerGate.complete();
      await cleanupFuture;
      await _settle();

      expect(
        repository.registeredFids,
        equals([const RegisteredFid(fid: "fid-1", platform: DevicePlatform.android)]),
      );
      expect(repository.unregisteredFids, equals(["fid-1"]));
    });

    test("a stalled logout cleanup does not block later push work", () {
      fakeAsync((async) {
        // Built inside the fake zone so its queue runs on fake time.
        final service = NotificationRegistrationService(
          repository: repository,
          authSession: authSession,
          pushMessagingSource: pushMessagingSource,
        );
        unawaited(service.start());
        async.flushMicrotasks();
        repository.stallNextUnregisterFid = true;

        Object? cleanupError;
        unawaited(service.unregisterCurrentDevice().catchError((Object error) => cleanupError = error));
        var resumed = false;
        unawaited(service.resumeRegistrationAfterFailedLogout().then((_) => resumed = true));
        async.elapse(const Duration(seconds: 5));

        expect(cleanupError, isA<TimeoutException>());
        expect(resumed, isTrue);

        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    });

    test("failed logout resumes registration for the authenticated user", () async {
      await service.start();
      await _settle();
      await service.unregisterCurrentDevice();

      await service.resumeRegistrationAfterFailedLogout();
      await _settle();
      pushMessagingSource.emitRegisteredFid("fid-2");
      await _settle();

      expect(
        repository.registeredFids,
        equals([
          const RegisteredFid(fid: "fid-1", platform: DevicePlatform.android),
          const RegisteredFid(fid: "fid-1", platform: DevicePlatform.android),
          const RegisteredFid(fid: "fid-2", platform: DevicePlatform.android),
        ]),
      );
      expect(repository.unregisteredFids, equals(["fid-1", "fid-1"]));
    });

    test("keeps listening after an initial registration failure", () async {
      pushMessagingSource.failNextRegister = true;

      await service.start();
      await _settle();

      expect(repository.registeredFids, isEmpty);

      authSession.emit(const AuthState.unauthenticated());
      await _settle();
      authSession.emit(_authenticatedState());
      await _settle();

      expect(
        repository.registeredFids,
        equals([const RegisteredFid(fid: "fid-1", platform: DevicePlatform.android)]),
      );

      pushMessagingSource.emitRegisteredFid("fid-2");
      await _settle();

      expect(repository.unregisteredFids, equals(["fid-1"]));
      expect(
        repository.registeredFids,
        equals([
          const RegisteredFid(fid: "fid-1", platform: DevicePlatform.android),
          const RegisteredFid(fid: "fid-2", platform: DevicePlatform.android),
        ]),
      );
    });

    // A registration the repository refuses (for example an unreadable device
    // id) must leave the FID unregistered, so the next report of it retries.
    test("retries a failed server registration on the next report of the same FID", () async {
      repository.failNextRegisterFid = true;
      await service.start();
      await _settle();

      expect(repository.registeredFids, isEmpty);

      pushMessagingSource.emitRegisteredFid("fid-1");
      await _settle();

      expect(
        repository.registeredFids,
        equals([const RegisteredFid(fid: "fid-1", platform: DevicePlatform.android)]),
      );
    });

    // Retiring the installation needs the network and runs only after auth was
    // cleared, so an offline failure must be logged without failing logout.
    test("a failed local unregister at logout is logged and logout still completes", () async {
      final sink = _RecordingLogSink();
      setLogSink(sink: sink);
      addTearDown(() => setLogSink(sink: const StdoutLogSink()));
      await service.start();
      await _settle();
      pushMessagingSource.failNextUnregister = true;

      await service.unregisterCurrentDevice();
      authSession.emit(const AuthState.unauthenticated());
      await _settle();

      expect(repository.unregisteredFids, equals(["fid-1"]));
      expect(pushMessagingSource.unregisterCalls, 1);
      expect(
        sink.records.where((record) => record.level == LogLevel.warning).map((record) => record.message),
        contains("Failed to sync push registration for auth state change"),
      );

      authSession.emit(_authenticatedState());
      await _settle();

      expect(pushMessagingSource.registerCalls, 2);
    });

    test("does not register an FID that arrives after sign-out during the initial sync", () async {
      final registerGate = Completer<void>();
      pushMessagingSource.registerGate = registerGate.future;

      final startFuture = service.start();
      authSession.emit(const AuthState.unauthenticated());

      registerGate.complete();
      await startFuture;
      await _settle();

      expect(repository.registeredFids, isEmpty);
      expect(repository.unregisteredFids, isEmpty);
      expect(pushMessagingSource.unregisterCalls, 2);
    });

    test("processes the first changed auth snapshot after startup sync", () async {
      final registerGate = Completer<void>();
      pushMessagingSource.registerGate = registerGate.future;

      final startFuture = service.start();
      authSession.emit(const AuthState.unauthenticated());
      authSession.emit(_authenticatedState());

      registerGate.complete();
      await startFuture;
      await _settle();

      expect(pushMessagingSource.registerCalls, 2);
      expect(
        repository.registeredFids,
        equals([const RegisteredFid(fid: "fid-1", platform: DevicePlatform.android)]),
      );
      expect(repository.unregisteredFids, isEmpty);
      expect(pushMessagingSource.unregisterCalls, 1);
    });
  });
}

/// Lets queued registration events and the work they enqueue finish.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

class _RecordingLogSink() implements LogSink {
  final records = <LogRecord>[];

  @override
  void write({required LogRecord record}) => records.add(record);

  @override
  Future<void> flush() async {}
}

class RecordingNotificationRepository({required final List<String> operations}) implements NotificationRepository {
  final List<RegisteredFid> registeredFids = <RegisteredFid>[];
  final List<String> unregisteredFids = <String>[];
  bool failNextRegisterFid = false;
  bool failNextUnregisterFid = false;
  bool stallNextUnregisterFid = false;

  @override
  Future<void> registerFid({required String fid, required DevicePlatform platform}) async {
    if (failNextRegisterFid) {
      failNextRegisterFid = false;
      throw StateError("register FID failed");
    }
    registeredFids.add(RegisteredFid(fid: fid, platform: platform));
    operations.add("register:$fid");
  }

  @override
  Future<void> unregisterFid({required String fid}) async {
    unregisteredFids.add(fid);
    operations.add("unregister:$fid");
    if (stallNextUnregisterFid) {
      stallNextUnregisterFid = false;
      return await Completer<void>().future;
    }
    if (failNextUnregisterFid) {
      failNextUnregisterFid = false;
      throw StateError("unregister FID failed");
    }
  }
}

@immutable
class const RegisteredFid({required final String fid, required final DevicePlatform platform}) {
  @override
  bool operator ==(Object other) {
    return other is RegisteredFid && other.fid == fid && other.platform == platform;
  }

  @override
  int get hashCode => Object.hash(fid, platform);
}

/// Mirrors the SDK: a registration delivers the FID as an event, never as a
/// return value.
class FakePushMessagingSource({
  required String fid,
  @override required final DevicePlatform devicePlatform,
  required final List<String> operations,
}) implements PushMessagingSource {
  final StreamController<String> _registeredFidController = StreamController<String>.broadcast();
  final StreamController<PushNotificationMessage> _foregroundMessageController =
      StreamController<PushNotificationMessage>.broadcast();
  final StreamController<NotificationOpenRequest> _notificationOpenedController =
      StreamController<NotificationOpenRequest>.broadcast();

  String currentFid = fid;
  Future<void>? registerGate;
  int registerCalls = 0;
  int unregisterCalls = 0;
  bool failNextRegister = false;
  bool failNextUnregister = false;

  @override
  Stream<PushNotificationMessage> get foregroundMessageStream => _foregroundMessageController.stream;

  @override
  Future<NotificationOpenRequest?> getInitialNotificationOpen() async => null;

  @override
  Future<void> register() async {
    registerCalls++;
    await registerGate;
    if (failNextRegister) {
      failNextRegister = false;
      throw StateError("register failed");
    }
    _registeredFidController.add(currentFid);
  }

  @override
  Future<void> unregister() async {
    unregisterCalls++;
    operations.add("unregister-local");
    if (failNextUnregister) {
      failNextUnregister = false;
      throw StateError("unregister failed");
    }
  }

  @override
  Future<void> initialize() async {}

  @override
  Stream<NotificationOpenRequest> get notificationOpenedStream => _notificationOpenedController.stream;

  @override
  Stream<String> get registeredFidStream => _registeredFidController.stream;

  void emitRegisteredFid(String fid) {
    currentFid = fid;
    _registeredFidController.add(fid);
  }

  Future<void> dispose() async {
    await _registeredFidController.close();
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
