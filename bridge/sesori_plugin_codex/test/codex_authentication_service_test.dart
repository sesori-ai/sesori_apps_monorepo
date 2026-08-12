import "dart:async";

import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/codex_stdio_app_server_client.dart";
import "package:codex_plugin/src/repositories/codex_authentication_repository.dart";
import "package:codex_plugin/src/services/codex_authentication_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("CodexAuthenticationService", () {
    test("emits a challenge then completion and cleans up", () async {
      final client = _FakeStdioClient();
      final repository = _FakeAuthenticationRepository();
      final service = CodexAuthenticationService(
        client: client,
        repository: repository,
        aborted: StartAbortSignal.never,
        requestTimeout: const Duration(seconds: 2),
      );

      final events = service.authenticate().toList();
      await repository.started;
      repository.complete();

      expect(
        await events,
        [
          isA<PluginAuthenticationDeviceCodeChallenge>()
              .having(
                (event) => event.verificationUri,
                "verificationUri",
                Uri.https("auth.example", "/device"),
              )
              .having((event) => event.userCode, "userCode", "PRIVATE-CODE"),
          isA<PluginAuthenticationCompleted>(),
        ],
      );
      expect(repository.disposed, isTrue);
      expect(client.disposed, isTrue);
    });

    test("aborts, cancels upstream, and cleans up", () async {
      final client = _FakeStdioClient();
      final repository = _FakeAuthenticationRepository();
      final abort = StartAbortController();
      final service = CodexAuthenticationService(
        client: client,
        repository: repository,
        aborted: abort.signal,
        requestTimeout: const Duration(seconds: 2),
      );
      final events = service.authenticate().toList();
      await repository.started;

      abort.abort();

      await expectLater(
        events,
        throwsA(isA<PluginStartAbortedException>()),
      );
      expect(repository.cancelled, isTrue);
      expect(repository.disposed, isTrue);
      expect(client.disposed, isTrue);
    });

    test("sanitizes repository failures and cleans up", () async {
      final client = _FakeStdioClient();
      final repository = _FakeAuthenticationRepository();
      final service = CodexAuthenticationService(
        client: client,
        repository: repository,
        aborted: StartAbortSignal.never,
        requestTimeout: const Duration(seconds: 2),
      );
      final events = service.authenticate().toList();
      await repository.started;
      await Future<void>.delayed(Duration.zero);
      repository.fail("private workspace policy detail");

      final result = await events;
      expect(
        result.last,
        isA<PluginAuthenticationFailed>().having(
          (event) => event.message,
          "message",
          isNot(contains("private workspace policy detail")),
        ),
      );
      expect(repository.disposed, isTrue);
      expect(client.disposed, isTrue);
    });

    test("sanitizes child connection failures and cleans up", () async {
      final client = _FakeStdioClient(
        connectError: StateError("private child process detail"),
      );
      final repository = _FakeAuthenticationRepository();
      final service = CodexAuthenticationService(
        client: client,
        repository: repository,
        aborted: StartAbortSignal.never,
        requestTimeout: const Duration(seconds: 2),
      );

      final events = await service.authenticate().toList();

      expect(events, hasLength(1));
      expect(
        events.single,
        isA<PluginAuthenticationFailed>().having(
          (event) => event.message,
          "message",
          isNot(contains("private child process detail")),
        ),
      );
      expect(repository.disposed, isTrue);
      expect(client.disposed, isTrue);
    });

    test("settles with failure when the child exits after challenge", () async {
      final client = _FakeStdioClient();
      final repository = _FakeAuthenticationRepository();
      final service = CodexAuthenticationService(
        client: client,
        repository: repository,
        aborted: StartAbortSignal.never,
        requestTimeout: const Duration(seconds: 2),
      );
      final events = service.authenticate().toList();
      await repository.started;
      await Future<void>.delayed(Duration.zero);

      client.exit(7);

      final result = await events.timeout(const Duration(milliseconds: 100));
      expect(result.first, isA<PluginAuthenticationDeviceCodeChallenge>());
      expect(result.last, isA<PluginAuthenticationFailed>());
      expect(repository.disposed, isTrue);
      expect(client.disposed, isTrue);
    });
  });
}

class _FakeAuthenticationRepository implements CodexAuthenticationRepository {
  final Completer<void> _started = Completer<void>();
  final Completer<void> _completion = Completer<void>();
  bool cancelled = false;
  bool disposed = false;

  Future<void> get started => _started.future;

  @override
  Future<CodexAuthenticationChallenge> start() async {
    _started.complete();
    return CodexAuthenticationChallenge(
      verificationUri: Uri.https("auth.example", "/device"),
      userCode: "PRIVATE-CODE",
    );
  }

  @override
  Future<void> waitForCompletion() => _completion.future;

  void complete() => _completion.complete();

  void fail(String detail) => _completion.completeError(
    CodexAuthenticationException(
      message: "Codex device login did not complete",
      cause: detail,
    ),
  );

  @override
  Future<void> cancel() async {
    cancelled = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class _FakeStdioClient implements CodexStdioAppServerClient {
  _FakeStdioClient({this.connectError});

  final Object? connectError;
  final Completer<int> _exit = Completer<int>();
  bool disposed = false;

  @override
  Future<CodexInitializeResult> connect({
    required String clientName,
    required String clientVersion,
    required Duration timeout,
  }) async {
    final error = connectError;
    if (error != null) throw error;
    return const CodexInitializeResult(
      userAgent: "codex_cli_rs/0.146.0",
      codexHome: "/private/codex-home",
      platformOs: "macos",
      platformFamily: "unix",
    );
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  void exit(int code) => _exit.complete(code);

  @override
  Stream<CodexServerNotification> get notifications => const Stream.empty();

  @override
  Future<int> get processExit => _exit.future;

  @override
  Future<dynamic> request({
    required String method,
    Object? params,
    Duration timeout = const Duration(seconds: 30),
  }) => throw UnimplementedError();

  @override
  Stream<CodexServerRequest> get serverRequests => const Stream.empty();
}
