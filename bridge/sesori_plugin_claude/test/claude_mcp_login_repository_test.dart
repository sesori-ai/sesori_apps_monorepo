import "dart:async";
import "dart:convert";
import "dart:io";

import "package:claude_plugin/claude_plugin.dart";
import "package:claude_plugin/src/repositories/parsers/claude_mcp_login_output_parser.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

final _authorization = Uri.https("issuer.example", "/authorize", {
  "state": "fixture-state",
  "redirect_uri": "http://localhost:4321/callback",
});
const _callback = "http://localhost:4321/callback?state=fixture-state&code=fixture-code";

void main() {
  group("MCP login challenge", () {
    test("extracts only OAuth challenges and keeps presentation private", () {
      const parser = ClaudeMcpLoginOutputParser();
      expect(parser.parseLine(line: "See https://docs.example/mcp"), isNull);
      final challenge = parser.parseLine(line: "\x1b]8;;$_authorization\x07$_authorization\x1b]8;;\x07")!;
      expect(challenge.authorizationUri, _authorization);
      expect(challenge.validateCallback(value: _callback).queryParameters["code"], "fixture-code");
      expect(challenge.toString(), isNot(contains("fixture-state")));
    });

    test("rejects mismatched state, destination and multiline input", () {
      final challenge = const ClaudeMcpLoginOutputParser().parseLine(line: "$_authorization")!;
      for (final value in [
        "code",
        _callback.replaceAll("fixture-state", "other-state"),
        _callback.replaceAll("4321", "4322"),
        _callback.replaceAll("/callback", "/other"),
        "$_callback\nsecond-line",
      ]) {
        expect(() => challenge.validateCallback(value: value), throwsFormatException);
      }
    });

    test("rejects ambiguous OAuth challenge and callback parameters", () {
      final challenge = const ClaudeMcpLoginOutputParser().parseLine(line: "$_authorization")!;
      for (final value in [
        "$_callback&state=fixture-state",
        "$_callback&code=other-code",
        "http://localhost:4321/callback?state=fixture-state&error=access_denied&error=server_error",
      ]) {
        expect(() => challenge.validateCallback(value: value), throwsFormatException);
      }
      for (final value in [
        "$_authorization&state=fixture-state",
        "$_authorization&redirect_uri=http%3A%2F%2Flocalhost%3A4321%2Fcallback",
      ]) {
        expect(() => const ClaudeMcpLoginOutputParser().parseLine(line: value), throwsFormatException);
      }
    });

    test("rejects missing state and non-loopback native callback", () {
      for (final params in [
        {"redirect_uri": "http://localhost:4321/callback"},
        {"state": "fixture-state", "redirect_uri": "https://remote.example/callback"},
      ]) {
        final uri = Uri.https("issuer.example", "/authorize", params);
        expect(() => const ClaudeMcpLoginOutputParser().parseLine(line: "$uri"), throwsFormatException);
      }
    });
  });

  group("native terminal login", skip: !(Platform.isMacOS || Platform.isLinux), () {
    late _Host host;
    late ClaudeMcpLoginRepository repository;
    late HostClaudeProcessFactory factory;

    setUp(() {
      host = _Host();
      factory = HostClaudeProcessFactory(processes: host, environment: const {"PATH": "/bin"});
      repository = ClaudeMcpLoginRepository(
        processFactory: factory,
        binaryPath: "/fixture/claude",
        serverName: "fixture",
        workingDirectory: "/fixture/project",
        environment: const {"CLAUDE_CONFIG_DIR": "/fixture/config"},
        killGrace: const Duration(milliseconds: 5),
      );
    });
    tearDown(() async {
      await repository.dispose();
      await factory.dispose();
    });

    test("reads fragmented output and completes on the real exit after callback submission", () async {
      final challenge = repository.start();
      await _pump();
      final bytes = utf8.encode("Visit $_authorization\n");
      host.process.output.add(bytes.sublist(0, 30));
      host.process.output.add(bytes.sublist(30));
      expect((await challenge).authorizationUri, _authorization);
      expect(host.executable, "/usr/bin/script");
      expect(host.arguments, contains("/dev/null"));
      expect(host.directory, "/fixture/project");
      expect(host.environment?["CLAUDE_CONFIG_DIR"], "/fixture/config");
      await expectLater(
        repository.submitCallback(callback: _callback.replaceAll("fixture-state", "wrong")),
        throwsA(isA<PluginMcpAuthenticationCallbackRejectedException>()),
      );
      expect(host.process.stdin.bytes, isEmpty);
      await repository.submitCallback(callback: _callback);
      expect(utf8.decode(host.process.stdin.bytes), "$_callback\n");
      host.process.finish(code: 7);
      expect(await repository.waitForExit(), 7);
      expect(host.signals, isEmpty);
    });

    test("native exit before a URL is an explicit failure", () async {
      final challenge = repository.start();
      final failed = expectLater(
        challenge,
        throwsA(isA<ClaudeMcpCommandExitedException>().having((e) => e.exitCode, "exitCode", 1)),
      );
      await _pump();
      host.process.finish(code: 1);
      await failed;
    });

    test("cancellation during spawn waits for and stops the owned child", () async {
      host.spawnGate = Completer<void>();
      final challenge = repository.start();
      final failed = expectLater(challenge, throwsA(isA<ClaudeMcpCommandExitedException>()));
      final disposal = repository.dispose();
      await _pump();
      expect(host.signals, isEmpty);
      host.spawnGate!.complete();
      await disposal;
      await failed;
      expect(host.signals, [ShutdownSignal.graceful]);
      expect(host.process.output.hasListener, isFalse);
    });

    test("forces a child that ignores graceful stop", () async {
      host.ignoreGraceful = true;
      final challenge = repository.start();
      final failed = expectLater(challenge, throwsA(isA<ClaudeMcpCommandExitedException>()));
      await _pump();
      await repository.dispose();
      await failed;
      expect(host.signals, [ShutdownSignal.graceful, ShutdownSignal.force]);
    });

    test("service emits authoritative completion after releasing the child", () async {
      final operation = await ClaudeMcpAuthenticationService(
        repository: _UnusedLogoutRepository(),
        resolveContext: ({required target}) async => _context,
        createLogin: ({required context}) => repository,
        urlBudget: const Duration(seconds: 90),
        overallBudget: const Duration(minutes: 10),
      ).begin(target: _target) as PluginMcpCancelableAuthentication;
      final events = <PluginMcpAuthenticationEvent>[];
      final done = operation.events.forEach(events.add);
      await _pump();
      host.process.output.add(utf8.encode("$_authorization\n"));
      await _pump();
      expect(events.single, isA<PluginMcpAuthenticationChallenge>());
      await operation.submitCallback(callbackUri: Uri.parse(_callback));
      host.process.finish(code: 0);
      await done;
      expect(events.last, isA<PluginMcpAuthenticationCompleted>());
      expect(host.process.output.hasListener, isFalse);
      expect(operation.effectScope, PluginMcpActionEffectScope.harness);
    });

    for (final (providerError, expectedReason) in [
      ("access_denied", PluginMcpAuthenticationFailureReason.declined),
      ("server_error", PluginMcpAuthenticationFailureReason.nativeFailure),
    ]) {
      test("provider $providerError stops the native child without submitting a code", () async {
        final operation = await ClaudeMcpAuthenticationService(
          repository: _UnusedLogoutRepository(),
          resolveContext: ({required target}) async => _context,
          createLogin: ({required context}) => repository,
          urlBudget: const Duration(seconds: 90),
          overallBudget: const Duration(minutes: 10),
        ).begin(target: _target) as PluginMcpCancelableAuthentication;
        final events = <PluginMcpAuthenticationEvent>[];
        final done = operation.events.forEach(events.add);
        await _pump();
        host.process.output.add(utf8.encode("$_authorization\n"));
        await _pump();
        await operation.submitCallback(
          callbackUri: Uri.parse(_callback).replace(
            queryParameters: {
              "state": "fixture-state",
              "error": providerError,
            },
          ),
        );
        await done;
        final failed = events.last as PluginMcpAuthenticationFailed;
        expect(failed.reason, expectedReason);
        expect(failed.cause.toString(), isNot(contains("fixture-state")));
        expect(
          (failed.cause as ClaudeMcpAuthenticationException).innerError,
          isA<ClaudeMcpProviderCallbackException>().having((error) => error.nativeError, "nativeError", providerError),
        );
        expect(host.process.stdin.bytes, isEmpty);
        expect(host.signals, [ShutdownSignal.graceful]);
      });
    }

    test("cancellation before listening prevents native login from starting", () async {
      final operation = await ClaudeMcpAuthenticationService(
        repository: _UnusedLogoutRepository(),
        resolveContext: ({required target}) async => _context,
        createLogin: ({required context}) => repository,
        urlBudget: const Duration(seconds: 90),
        overallBudget: const Duration(minutes: 10),
      ).begin(target: _target) as PluginMcpCancelableAuthentication;
      await operation.cancel();
      final done = operation.events.toList();
      await _pump();
      try {
        expect(host.executable, isNull);
      } finally {
        host.process.finish(code: 1);
        await done;
      }
    });

    test("a provider callback racing cancellation cannot replace cancellation", () async {
      final operation = await ClaudeMcpAuthenticationService(
        repository: _UnusedLogoutRepository(),
        resolveContext: ({required target}) async => _context,
        createLogin: ({required context}) => repository,
        urlBudget: const Duration(seconds: 90),
        overallBudget: const Duration(minutes: 10),
      ).begin(target: _target) as PluginMcpCancelableAuthentication;
      final events = <PluginMcpAuthenticationEvent>[];
      final done = operation.events.forEach(events.add);
      await _pump();
      host.process.output.add(utf8.encode("$_authorization\n"));
      await _pump();
      final submission = operation.submitCallback(
        callbackUri: Uri.parse(_callback).replace(
          queryParameters: {"state": "fixture-state", "error": "access_denied"},
        ),
      );
      await operation.cancel();
      await submission;
      await done;
      expect(events, hasLength(1));
      expect(events.single, isA<PluginMcpAuthenticationChallenge>());
    });

    test("logout commands do not publish session binary health", () async {
      final health = <ProcessSpawnOutcome>[];
      final subscription = factory.events.listen(health.add);
      final logout = ClaudeMcpAuthenticationRepository(
        processFactory: factory,
        binaryPath: "/fixture/claude",
        commandBudget: const Duration(seconds: 30),
      ).forget(context: _context);
      await _pump();
      host.process.finish(code: 0);
      await logout;
      await _pump();
      await subscription.cancel();
      expect(health, isEmpty);
    });

    test("logout timeout releases pipes even when native exit precedes pipe closure", () async {
      final logout = ClaudeMcpAuthenticationRepository(
        processFactory: factory,
        binaryPath: "/fixture/claude",
        commandBudget: const Duration(milliseconds: 20),
      ).forget(context: _context);
      final failed = expectLater(logout, throwsA(isA<TimeoutException>()));
      host.process.exit.complete(0);
      await failed;
      expect(host.process.output.hasListener, isFalse);
      expect(host.process.errors.hasListener, isFalse);
      expect(host.signals, isEmpty);
      await host.process.output.close();
      await host.process.errors.close();
    });

    test("context read failure remains a typed failure with a private presentation", () async {
      final cause = TimeoutException("fixture-private-authorization");
      final service = ClaudeMcpAuthenticationService(
        repository: _UnusedLogoutRepository(),
        resolveContext: ({required target}) async => throw cause,
        createLogin: ({required context}) => repository,
        urlBudget: const Duration(seconds: 90),
        overallBudget: const Duration(minutes: 10),
      );
      await expectLater(
        service.begin(target: _target),
        throwsA(
          isA<ClaudeMcpAuthenticationException>()
              .having((error) => error.innerError, "cause", same(cause))
              .having((error) => error.toString(), "presentation", isNot(contains("fixture-private-authorization"))),
        ),
      );
      await expectLater(
        service.forget(target: _target),
        throwsA(
          isA<ClaudeMcpAuthenticationException>()
              .having((error) => error.innerError, "cause", same(cause))
              .having((error) => error.toString(), "presentation", isNot(contains("fixture-private-authorization"))),
        ),
      );
      expect(host.executable, isNull);
    });

    test("URL deadline expires and releases the native child", () async {
      final operation = await ClaudeMcpAuthenticationService(
        repository: _UnusedLogoutRepository(),
        resolveContext: ({required target}) async => _context,
        createLogin: ({required context}) => repository,
        urlBudget: const Duration(milliseconds: 10),
        overallBudget: const Duration(seconds: 1),
      ).begin(target: _target);
      final events = await operation.events.toList().timeout(const Duration(seconds: 1));
      expect((events.single as PluginMcpAuthenticationFailed).reason, PluginMcpAuthenticationFailureReason.expired);
      expect(host.signals, [ShutdownSignal.graceful]);
    });
  });
}

const _target = PluginMcpServerTarget(
  scope: PluginMcpSessionScope(sessionId: "fixture-session"),
  serverKey: "fixture",
);

const _context = ClaudeMcpAuthenticationContext(serverName: "fixture", workingDirectory: "/fixture/project");

class _UnusedLogoutRepository() implements ClaudeMcpAuthenticationRepository {
  @override
  Future<void> forget({required ClaudeMcpAuthenticationContext context}) async => throw UnimplementedError();
}

Future<void> _pump() async {
  for (var turn = 0; turn < 10; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Host() implements HostProcessService {
  final _Process process = _Process();
  final List<ShutdownSignal> signals = [];
  Completer<void>? spawnGate;
  bool ignoreGraceful = false;
  String? executable;
  List<String>? arguments;
  String? directory;
  Map<String, String>? environment;

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
    required bool includeParentEnvironment,
  }) async {
    this.executable = executable;
    this.arguments = arguments;
    this.environment = environment;
    directory = workingDirectory;
    await spawnGate?.future;
    return process;
  }

  @override
  Future<SignalResult> signalGraceful({required int pid}) async {
    signals.add(ShutdownSignal.graceful);
    if (!ignoreGraceful) process.finish(code: -15);
    return _result(pid: pid, force: false);
  }

  @override
  Future<SignalResult> signalForce({required int pid}) async {
    signals.add(ShutdownSignal.force);
    process.finish(code: -9);
    return _result(pid: pid, force: true);
  }

  SignalResult _result({required int pid, required bool force}) => SignalResult(
    pid: pid,
    requestedSignal: force ? ShutdownSignal.force : ShutdownSignal.graceful,
    deliveredSignal: force ? ProcessSignal.sigkill : ProcessSignal.sigterm,
    wasRequested: true,
    attemptedAt: DateTime.utc(2026, 10, 13),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Process() implements SpawnedProcess {
  final StreamController<List<int>> output = StreamController();
  final StreamController<List<int>> errors = StreamController();
  final Completer<int> exit = Completer();
  @override
  final _Input stdin = _Input();
  @override
  int get pid => 123;
  @override
  Stream<List<int>> get stdout => output.stream;
  @override
  Stream<List<int>> get stderr => errors.stream;
  @override
  Future<int> get exitCode => exit.future;
  void finish({required int code}) {
    if (exit.isCompleted) return;
    exit.complete(code);
    unawaited(output.close());
    unawaited(errors.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Input() implements IOSink {
  final List<int> bytes = [];
  final Completer<void> closed = Completer();
  @override
  void add(List<int> data) => bytes.addAll(data);
  @override
  Future<void> flush() async {}
  @override
  Future<void> get done => closed.future;
  @override
  Future<void> close() async {
    if (!closed.isCompleted) closed.complete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
