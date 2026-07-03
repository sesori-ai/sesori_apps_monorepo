import "dart:async";
import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;
import "package:rxdart/rxdart.dart";
import "package:sesori_bridge/src/auth/access_token_provider.dart";
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/bridge/api/filesystem_api.dart";
import "package:sesori_bridge/src/bridge/api/git_cli_api.dart";
import "package:sesori_bridge/src/bridge/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/bridge/models/bridge_config.dart";
import "package:sesori_bridge/src/bridge/orchestrator.dart";
import "package:sesori_bridge/src/bridge/persistence/database.dart";
import "package:sesori_bridge/src/bridge/relay_client.dart";
import "package:sesori_bridge/src/bridge/repositories/agent_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/health_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/permission_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/project_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/provider_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/pull_request_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/question_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/worktree_repository.dart";
import "package:sesori_bridge/src/bridge/services/project_initialization_service.dart";
import "package:sesori_bridge/src/bridge/services/session_event_enrichment_service.dart";
import "package:sesori_bridge/src/bridge/services/session_persistence_service.dart";
import "package:sesori_bridge/src/bridge/services/session_unseen_service.dart";
import "package:sesori_bridge/src/bridge/services/session_view_tracker.dart";
import "package:sesori_bridge/src/bridge/services/worktree_service.dart";
import "package:sesori_bridge/src/push/completion_notifier.dart";
import "package:sesori_bridge/src/push/completion_push_listener.dart";
import "package:sesori_bridge/src/push/maintenance_push_listener.dart";
import "package:sesori_bridge/src/push/push_dispatcher.dart";
import "package:sesori_bridge/src/push/push_maintenance_telemetry.dart";
import "package:sesori_bridge/src/push/push_notification_client.dart";
import "package:sesori_bridge/src/push/push_notification_content_builder.dart";
import "package:sesori_bridge/src/push/push_rate_limiter.dart";
import "package:sesori_bridge/src/push/push_session_state_tracker.dart";
import "package:sesori_shared/sesori_shared.dart" hide PermissionReply;
import "package:test/test.dart";

import "../helpers/restart_test_support.dart";
import "../helpers/test_database.dart";
import "../helpers/test_helpers.dart";
import "routing/routing_test_helpers.dart";

void main() {
  group("OrchestratorSession token re-auth", () {
    test("a token update whose identity cannot be parsed re-authenticates the relay", () async {
      final authority = _ScriptedTokenAuthority("token-1");
      final harness = await _ReauthHarness.start(authority: authority);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      final firstAuth = await _firstTextMessage(firstSocket);
      expect(firstAuth["token"], equals("token-1"));

      // A changed token that is not a parseable JWT (opaque test tokens here)
      // cannot prove the rotation kept the same identity, so the orchestrator
      // must conservatively drop and reconnect on the new token.
      authority.emit("token-2");

      final secondSocket = await harness.relayServer.nextClient();
      final secondAuth = await _firstTextMessage(secondSocket);
      expect(secondAuth["token"], equals("token-2"), reason: "relay re-authenticated on the new token");
    });

    test("a same-user token rotation does not drop the relay connection", () async {
      final initialToken = _jwt(userId: "user-1", seq: 1);
      final authority = _ScriptedTokenAuthority(initialToken);
      final harness = await _ReauthHarness.start(authority: authority);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      final firstAuth = await _firstTextMessage(firstSocket);
      expect(firstAuth["token"], equals(initialToken));

      // A routine refresh mints a DIFFERENT token for the SAME user (rotated
      // exp/signature) — e.g. TokenManager refreshing near expiry during session
      // metadata generation. The relay validates the JWT once at connect and
      // never re-checks it, so the live socket must stay up.
      authority.emit(_jwt(userId: "user-1", seq: 2));

      await Future<void>.delayed(const Duration(seconds: 1));
      expect(
        harness.relayServer.acceptedClientCount,
        equals(1),
        reason: "same-identity rotation must not re-auth",
      );
    });

    test("a token for a different user re-authenticates the relay", () async {
      final authority = _ScriptedTokenAuthority(_jwt(userId: "user-1", seq: 1));
      final harness = await _ReauthHarness.start(authority: authority);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      // Account switch: the pushed token belongs to a different user, so the
      // socket's authenticated identity is stale — drop and reconnect.
      final switchedToken = _jwt(userId: "user-2", seq: 2);
      authority.emit(switchedToken);

      final secondSocket = await harness.relayServer.nextClient();
      final secondAuth = await _firstTextMessage(secondSocket);
      expect(secondAuth["token"], equals(switchedToken), reason: "relay re-authenticated as the new user");
    });

    test("a routine pull re-emitting the same token does not drop the connection", () async {
      final authority = _ScriptedTokenAuthority("token-1");
      final harness = await _ReauthHarness.start(authority: authority);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      // A routine pull (e.g. metadata generation) re-emits the SAME token value
      // the socket already authenticated with. This must NOT re-auth/flap the
      // live connection.
      authority.emit("token-1");
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(harness.relayServer.acceptedClientCount, equals(1), reason: "unchanged token must not re-auth");
    });

    test("a relay drop while signed out does not reconnect with a stale token", () async {
      final authority = _ScriptedTokenAuthority("token-1");
      final harness = await _ReauthHarness.start(authority: authority);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      // Sign out: the next force-refresh (the reconnect pre-pull) fails, so the
      // reconnect must be deferred — the relay must NOT re-auth from the stale
      // cached token.
      authority.failRefresh = true;
      await firstSocket.close();

      // Give the reconnect loop several backoff iterations; none should connect.
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(harness.relayServer.acceptedClientCount, equals(1), reason: "no reconnect while signed out");

      // Signing back in lets the deferred reconnect proceed.
      authority
        ..failRefresh = false
        ..current = "token-restored";
      final secondSocket = await harness.relayServer.nextClient(timeout: const Duration(seconds: 10));
      final secondAuth = await _firstTextMessage(secondSocket);
      expect(secondAuth["token"], equals("token-restored"));
    });

    test("a transient refresh failure still reconnects with the cached token", () async {
      final authority = _ScriptedTokenAuthority("token-1");
      final harness = await _ReauthHarness.start(authority: authority);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      // The refresher fails transiently (not a typed unavailable / sign-out), as
      // a standalone TokenManager would when its auth-refresh endpoint is down
      // but the cached JWT is still valid. The reconnect must still proceed using
      // the cached token rather than deferring.
      authority.transientFailRefresh = true;
      await firstSocket.close();

      final secondSocket = await harness.relayServer.nextClient(timeout: const Duration(seconds: 10));
      final secondAuth = await _firstTextMessage(secondSocket);
      expect(secondAuth["token"], equals("token-1"), reason: "reconnect uses the cached token");
    });

    test("a token update racing a bridgeRevoked close still re-registers fresh", () async {
      final authority = _ScriptedTokenAuthority("token-1");
      final harness = await _ReauthHarness.start(authority: authority);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);
      expect(harness.registrationRepository.registeredBridgeIds, equals(<String?>[null]));

      // The relay revokes this bridge, then a token update is pushed after the
      // socket has closed but (typically) before the read loop has observed the
      // termination — the window the live re-auth guard protects. The re-auth
      // must NOT discard the channel (which would erase the bridgeRevoked close
      // code and make the bridge retry with the revoked id); the reconnect must
      // observe the revoked code and re-register fresh.
      harness.registrationRepository.nextBridgeId = "br_revoked-fresh";
      await firstSocket.close(RelayCloseCodes.bridgeRevoked);
      // Let the client observe the close (closeCode latches) before the push, so
      // the guard sees a non-null close code.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      authority.emit("token-2");

      final secondSocket = await harness.relayServer.nextClient(timeout: const Duration(seconds: 10));
      final secondAuth = await _firstTextMessage(secondSocket);

      // A second registration ran (the revoked path), both posting bridgeId=null
      // (never the revoked id), and the new socket authenticates with the fresh id.
      expect(harness.registrationRepository.registeredBridgeIds.length, greaterThanOrEqualTo(2));
      expect(harness.registrationRepository.registeredBridgeIds, everyElement(isNull));
      expect(secondAuth["bridgeId"], equals("br_revoked-fresh"));
    });

    test("a refresh failure with no cached token does not reconnect", () async {
      final authority = _ScriptedTokenAuthority("token-1");
      final harness = await _ReauthHarness.start(authority: authority);
      addTearDown(harness.close);

      final firstSocket = await harness.relayServer.nextClient();
      await _firstTextMessage(firstSocket);

      // The refresh fails for a non-unavailable reason, but there is also no
      // usable cached token (e.g. the token store was deleted on logout). There
      // is nothing safe to reconnect with, so the reconnect must be deferred.
      authority
        ..transientFailRefresh = true
        ..cachedTokenAvailable = false;
      await firstSocket.close();

      await Future<void>.delayed(const Duration(seconds: 2));
      expect(harness.relayServer.acceptedClientCount, equals(1), reason: "no reconnect without a safe token");

      // Once a token is available again the deferred reconnect proceeds.
      authority
        ..transientFailRefresh = false
        ..cachedTokenAvailable = true
        ..current = "token-recovered";
      final secondSocket = await harness.relayServer.nextClient(timeout: const Duration(seconds: 10));
      final secondAuth = await _firstTextMessage(secondSocket);
      expect(secondAuth["token"], equals("token-recovered"));
    });
  });
}

Future<Map<String, dynamic>> _firstTextMessage(WebSocket socket) async {
  final message = await socket.firstWhere((dynamic data) => data is String).timeout(const Duration(seconds: 5));
  return jsonDecodeMap(message as String);
}

/// Crafts an unsigned JWT carrying a `userId` claim. [seq] varies the payload
/// and signature placeholder so two tokens for the same user still compare
/// unequal as strings — mirroring a real rotation where exp and signature
/// change while the identity stays put. The identity gate only decodes the
/// payload segment, so the fake header/signature are irrelevant.
String _jwt({required String userId, required int seq}) {
  final payload = base64Url.encode(utf8.encode(jsonEncode({"userId": userId, "seq": seq}))).replaceAll("=", "");
  return "header.$payload.sig-$seq";
}

/// A controllable stand-in for [ControlChannelTokenService]: it is both the
/// access-token provider (sync getter + replayed stream) and the refresher used
/// by the reconnect pre-pull. Tests drive token pushes via [emit] and simulate a
/// signed-out GUI via [failRefresh].
class _ScriptedTokenAuthority implements AccessTokenProvider, TokenRefresher {
  final BehaviorSubject<String> _subject;
  String current;
  bool failRefresh = false;
  bool transientFailRefresh = false;
  // When false, the synchronous getter throws — mirroring a service whose cache
  // is empty or sign-out-invalidated (no safe token to reconnect with).
  bool cachedTokenAvailable = true;

  _ScriptedTokenAuthority(this.current) : _subject = BehaviorSubject<String>.seeded(current);

  /// Pushes a new token, mirroring the service caching a `token_update`.
  void emit(String token) {
    current = token;
    _subject.add(token);
  }

  @override
  String get accessToken {
    if (!cachedTokenAvailable) {
      throw StateError("no cached token");
    }
    return current;
  }

  @override
  ValueStream<String> get tokenStream => _subject.stream;

  @override
  Future<String> getAccessToken({bool forceRefresh = false}) async {
    if (failRefresh) {
      // Mirror the supervised service: a signed-out / mid-login GUI surfaces a
      // typed unavailable failure (the orchestrator defers reconnect on this).
      throw const ControlTokenUnavailableException("signed out");
    }
    if (transientFailRefresh) {
      // Mirror a standalone TokenManager whose auth-refresh endpoint is
      // transiently down while a valid cached token is still on hand. The
      // orchestrator must reconnect with the cached token rather than defer.
      throw const _TransientRefreshException();
    }
    return current;
  }

  Future<void> dispose() => _subject.close();
}

class _TransientRefreshException implements Exception {
  const _TransientRefreshException();
}

class _ReauthHarness {
  final OrchestratorSession session;
  final Future<void> runFuture;
  final _CountingRelayServer relayServer;
  final AppDatabase database;
  final _ScriptedTokenAuthority authority;
  final FakeBridgeRegistrationRepository registrationRepository;

  _ReauthHarness._({
    required this.session,
    required this.runFuture,
    required this.relayServer,
    required this.database,
    required this.authority,
    required this.registrationRepository,
  });

  static Future<_ReauthHarness> start({
    required _ScriptedTokenAuthority authority,
  }) async {
    final relayServer = await _CountingRelayServer.start();
    final database = createTestDatabase();
    final plugin = FakeBridgePlugin();
    final registrationRepository = FakeBridgeRegistrationRepository()..nextBridgeId = "br_initial";

    final pullRequestRepository = PullRequestRepository(
      pullRequestDao: database.pullRequestDao,
      projectsDao: database.projectsDao,
    );
    final sessionRepository = SessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      pullRequestRepository: pullRequestRepository,
      unseenCalculator: const SessionUnseenCalculator(),
    );
    final sessionViewTracker = SessionViewTracker();
    final sessionUnseenService = SessionUnseenService(
      unseenRepository: SessionUnseenRepository(
        sessionDao: database.sessionDao,
        projectsDao: database.projectsDao,
        db: database,
        calculator: const SessionUnseenCalculator(),
      ),
      projectRepository: ProjectRepository(
        plugin: plugin,
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
      ),
      viewTracker: sessionViewTracker,
    );
    final pushSubsystem = _createPushSubsystem();
    // One registration service feeds both the orchestrator and the relay client's
    // bridge-id provider, mirroring production — so the auth message reflects the
    // id the revoked path re-registers.
    final registrationService = createFakeBridgeRegistrationService(repository: registrationRepository);

    final orchestrator = Orchestrator(
      config: BridgeConfig(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        pluginEndpoint: "http://127.0.0.1:4096",
        authBackendURL: "http://127.0.0.1:8080",
        sseReplayWindow: const Duration(minutes: 1),
      ),
      client: RelayClient(
        relayURL: "ws://127.0.0.1:${relayServer.port}",
        accessTokenProvider: authority,
        bridgeIdProvider: registrationService,
      ),
      plugin: plugin,
      metadataService: FakeMetadataService(),
      pushDispatcher: pushSubsystem.dispatcher,
      completionListener: pushSubsystem.completionListener,
      maintenanceListener: pushSubsystem.maintenanceListener,
      accessTokenProvider: authority,
      tokenRefresher: authority,
      bridgeRegistrationService: registrationService,
      failureReporter: FakeFailureReporter(),
      prSyncService: FakePrSyncService(),
      sessionRepository: sessionRepository,
      projectRepository: ProjectRepository(
        plugin: plugin,
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        unseenCalculator: const SessionUnseenCalculator(),
      ),
      sessionUnseenService: sessionUnseenService,
      sessionViewTracker: sessionViewTracker,
      filesystemRepository: FilesystemRepository(
        filesystemApi: const FilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
      ),
      projectInitializationService: ProjectInitializationService(
        worktreeRepository: WorktreeRepository(
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          plugin: plugin,
          gitApi: GitCliApi(
            processRunner: ProcessRunner(),
            gitPathExists: ({required String gitPath}) => false,
          ),
        ),
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
      ),
      healthRepository: HealthRepository(
        plugin: plugin,
        bridgeVersion: "0.0.0-test",
        filesystemAccessOk: true,
      ),
      providerRepository: ProviderRepository(plugin: plugin),
      agentRepository: AgentRepository(plugin: plugin),
      permissionRepository: PermissionRepository(plugin: plugin),
      questionRepository: QuestionRepository(plugin: plugin),
      sessionPersistenceService: SessionPersistenceService(
        projectsDao: database.projectsDao,
        sessionDao: database.sessionDao,
        db: database,
      ),
      worktreeService: WorktreeService(
        worktreeRepository: WorktreeRepository(
          projectsDao: database.projectsDao,
          sessionDao: database.sessionDao,
          gitApi: GitCliApi(
            processRunner: ProcessRunner(),
            gitPathExists: ({required String gitPath}) => false,
          ),
          plugin: plugin,
        ),
      ),
      sessionEventEnrichmentService: SessionEventEnrichmentService(
        sessionRepository: sessionRepository,
        failureReporter: FakeFailureReporter(),
      ),
      restartService: buildTestRestartService(),
    );

    final session = orchestrator.create();
    final runFuture = session.run();
    unawaited(runFuture.catchError((_) {}));

    return _ReauthHarness._(
      session: session,
      runFuture: runFuture,
      relayServer: relayServer,
      database: database,
      authority: authority,
      registrationRepository: registrationRepository,
    );
  }

  Future<void> close() async {
    await session.cancel();
    try {
      await runFuture.timeout(const Duration(seconds: 10));
    } on Object {
      // run() may have already completed.
    }
    await authority.dispose();
    await database.close();
    await relayServer.close();
  }
}

/// Thin pass-through over [TestRelayServer]. Reconnect assertions read
/// [acceptedClientCount], which the server increments when it ACCEPTS a socket
/// (not when a test consumes one), so a spurious reconnect that sits buffered is
/// still observed by a "no reconnect" assertion.
class _CountingRelayServer {
  final TestRelayServer _inner;

  _CountingRelayServer._(this._inner);

  static Future<_CountingRelayServer> start() async {
    return _CountingRelayServer._(await TestRelayServer.start());
  }

  int get port => _inner.port;

  int get acceptedClientCount => _inner.acceptedClientCount;

  Future<WebSocket> nextClient({Duration timeout = const Duration(seconds: 5)}) async {
    return _inner.nextClient().timeout(timeout);
  }

  Future<void> close() => _inner.close();
}

typedef _TestPushSubsystem = ({
  PushDispatcher dispatcher,
  CompletionPushListener completionListener,
  MaintenancePushListener maintenanceListener,
});

_TestPushSubsystem _createPushSubsystem() {
  final tracker = PushSessionStateTracker(now: DateTime.now);
  final completionNotifier = CompletionNotifier(tracker: tracker);
  final rateLimiter = PushRateLimiter();
  final telemetryBuilder = PushMaintenanceTelemetryBuilder(
    completionNotifier: completionNotifier,
    rateLimiter: rateLimiter,
    rssBytesReader: () => null,
  );
  final dispatcher = PushDispatcher(
    client: _NoopPushNotificationClient(),
    rateLimiter: rateLimiter,
    tracker: tracker,
    contentBuilder: const PushNotificationContentBuilder(),
  );
  return (
    dispatcher: dispatcher,
    completionListener: CompletionPushListener(
      tracker: tracker,
      completionNotifier: completionNotifier,
      contentBuilder: const PushNotificationContentBuilder(),
      dispatcher: dispatcher,
    ),
    maintenanceListener: MaintenancePushListener(
      tracker: tracker,
      completionNotifier: completionNotifier,
      rateLimiter: rateLimiter,
      telemetryBuilder: telemetryBuilder,
      maintenanceInterval: const Duration(minutes: 10),
    ),
  );
}

class _NoopPushNotificationClient extends PushNotificationClient {
  _NoopPushNotificationClient()
    : super(
        authBackendURL: "http://127.0.0.1:8080",
        tokenRefreshManager: FakeTokenRefresher(),
        client: http.Client(),
      );

  @override
  Future<void> sendNotification(SendNotificationPayload payload) async {}
}
