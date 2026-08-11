import "dart:async";
import "dart:convert";
import "dart:io";

import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/codex_stdio_app_server_client.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const environment = <String, String>{
    "CODEX_HOME": "/private/codex-home",
    "HTTPS_PROXY": "https://proxy.example",
  };

  CodexStdioAppServerClient client(
    _FakeHostProcessService processes,
  ) => CodexStdioAppServerClient(
    processes: processes,
    executable: "/managed/codex",
    environment: environment,
    shutdownTimeout: const Duration(milliseconds: 10),
  );

  Future<({Future<CodexInitializeResult> future})> startConnect(
    CodexStdioAppServerClient appServerClient,
    _FakeProcess process,
  ) async {
    final connect = appServerClient.connect(
      clientName: "sesori-bridge",
      clientVersion: "1.2.3",
      timeout: const Duration(seconds: 1),
    );
    await process.waitForFrames(1);
    return (future: connect);
  }

  void completeInitialize(_FakeProcess process) {
    final id = process.frames.single["id"];
    process.send({
      "id": id,
      "result": {
        "userAgent": "codex_cli_rs/0.146.0",
        "codexHome": "/private/codex-home",
        "platformOs": "macos",
        "platformFamily": "unix",
      },
    });
  }

  group("CodexStdioAppServerClient", () {
    test("spawns stdio app-server and completes the handshake", () async {
      final process = _FakeProcess(autoExitOnStdinClose: true);
      final processes = _FakeHostProcessService(process);
      final appServerClient = client(processes);
      final connect = (await startConnect(appServerClient, process)).future;

      expect(processes.executable, "/managed/codex");
      expect(processes.arguments, ["app-server", "--listen", "stdio://"]);
      expect(processes.environment, environment);
      expect(process.frames.single, {
        "id": 1,
        "method": "initialize",
        "params": {
          "clientInfo": {
            "name": "sesori-bridge",
            "title": "Sesori Bridge",
            "version": "1.2.3",
          },
        },
      });

      completeInitialize(process);
      final result = await connect;
      await process.waitForFrames(2);
      expect(result.userAgent, "codex_cli_rs/0.146.0");
      expect(process.frames.last, {"method": "initialized"});

      await appServerClient.dispose();
      expect(process.stdinClosed, isTrue);
    });

    test("correlates fragmented responses and coalesced notifications", () async {
      final process = _FakeProcess(autoExitOnStdinClose: true);
      final appServerClient = client(_FakeHostProcessService(process));
      final connect = (await startConnect(appServerClient, process)).future;
      completeInitialize(process);
      await connect;
      await process.waitForFrames(2);

      final notifications = <CodexServerNotification>[];
      final subscription = appServerClient.notifications.listen(
        notifications.add,
      );
      final request = appServerClient.request(
        method: "account/login/start",
        params: const {"type": "chatgptDeviceCode"},
      );
      await process.waitForFrames(3);
      final requestId = process.frames.last["id"];
      final response = jsonEncode({
        "id": requestId,
        "result": {"ok": true},
      });
      process.stdoutController.add(utf8.encode(response.substring(0, 8)));
      process.stdoutController.add(
        utf8.encode(
          "${response.substring(8)}\n"
          '${jsonEncode({
            "method": "first",
            "params": {"value": 1},
          })}\n'
          '${jsonEncode({
            "method": "second",
            "params": {"value": 2},
          })}\n',
        ),
      );

      expect(await request, {"ok": true});
      await _eventLoop();
      expect(notifications.map((notification) => notification.method), [
        "first",
        "second",
      ]);

      await subscription.cancel();
      await appServerClient.dispose();
    });

    test("surfaces typed RPC errors with the originating method", () async {
      final process = _FakeProcess(autoExitOnStdinClose: true);
      final appServerClient = client(_FakeHostProcessService(process));
      final connect = (await startConnect(appServerClient, process)).future;
      completeInitialize(process);
      await connect;
      await process.waitForFrames(2);

      final request = appServerClient.request(
        method: "account/login/start",
      );
      await process.waitForFrames(3);
      process.send({
        "id": process.frames.last["id"],
        "error": {"code": -32600, "message": "private policy detail"},
      });

      await expectLater(
        request,
        throwsA(
          isA<CodexRpcException>()
              .having(
                (error) => error.method,
                "method",
                "account/login/start",
              )
              .having((error) => error.code, "code", -32600),
        ),
      );
      await appServerClient.dispose();
    });

    test("fails pending requests on malformed JSON and process exit", () async {
      final process = _FakeProcess(autoExitOnStdinClose: true);
      final appServerClient = client(_FakeHostProcessService(process));
      final connect = (await startConnect(appServerClient, process)).future;
      completeInitialize(process);
      await connect;
      await process.waitForFrames(2);

      final malformedRequest = appServerClient.request(method: "first");
      await process.waitForFrames(3);
      process.stdoutController.add(
        utf8.encode("not-json-CODE-PRIVATE\n"),
      );
      await expectLater(malformedRequest, throwsA(isA<StateError>()));

      final exitedRequest = appServerClient.request(method: "second");
      await process.waitForFrames(4);
      process.completeExit(7);
      await expectLater(exitedRequest, throwsA(isA<StateError>()));
      await expectLater(
        appServerClient.request(method: "after-exit"),
        throwsA(isA<StateError>()),
      );
      await appServerClient.dispose();
    });

    test("cleans up after initialization failure", () async {
      final process = _FakeProcess(autoExitOnStdinClose: true);
      final appServerClient = client(_FakeHostProcessService(process));
      final connect = (await startConnect(appServerClient, process)).future;
      process.send({
        "id": process.frames.single["id"],
        "error": {"code": -32600, "message": "Not initialized"},
      });

      await expectLater(connect, throwsA(isA<CodexRpcException>()));
      expect(process.stdinClosed, isTrue);
      await appServerClient.dispose();
    });

    test("escalates bounded cleanup from graceful to force", () async {
      final process = _FakeProcess(autoExitOnStdinClose: false);
      final processes = _FakeHostProcessService(
        process,
        exitOnForceSignal: true,
      );
      final appServerClient = client(processes);
      final connect = (await startConnect(appServerClient, process)).future;
      completeInitialize(process);
      await connect;

      await appServerClient.dispose();

      expect(processes.gracefulPids, [process.pid]);
      expect(processes.forcePids, [process.pid]);
      expect(await process.exitCode, -9);
    });
  });
}

Future<void> _eventLoop() => Future<void>.delayed(Duration.zero);

class _FakeHostProcessService implements HostProcessService {
  _FakeHostProcessService(
    this.process, {
    this.exitOnForceSignal = false,
  });

  final _FakeProcess process;
  final bool exitOnForceSignal;
  String? executable;
  List<String>? arguments;
  Map<String, String>? environment;
  final List<int> gracefulPids = <int>[];
  final List<int> forcePids = <int>[];

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) async {
    this.executable = executable;
    this.arguments = arguments;
    this.environment = environment;
    return process;
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => null;

  @override
  Future<SignalResult> signalGraceful({required int pid}) async {
    gracefulPids.add(pid);
    return _signal(pid: pid, shutdownSignal: ShutdownSignal.graceful);
  }

  @override
  Future<SignalResult> signalForce({required int pid}) async {
    forcePids.add(pid);
    if (exitOnForceSignal) process.completeExit(-9);
    return _signal(pid: pid, shutdownSignal: ShutdownSignal.force);
  }

  SignalResult _signal({
    required int pid,
    required ShutdownSignal shutdownSignal,
  }) => SignalResult(
    pid: pid,
    requestedSignal: shutdownSignal,
    deliveredSignal: shutdownSignal == ShutdownSignal.force ? ProcessSignal.sigkill : ProcessSignal.sigterm,
    wasRequested: true,
    attemptedAt: DateTime.utc(2026, 8, 11),
  );
}

class _FakeProcess implements SpawnedProcess {
  _FakeProcess({required this.autoExitOnStdinClose}) {
    _stdinController = StreamController<List<int>>(
      onListen: () {},
      onCancel: () {},
    );
    _stdin = IOSink(_stdinController.sink);
    _stdinSubscription = _stdinController.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            frames.add((jsonDecode(line) as Map).cast<String, dynamic>());
            _frameChanged.add(null);
          },
          onDone: () {
            stdinClosed = true;
            if (autoExitOnStdinClose) completeExit(0);
          },
        );
  }

  static int _nextPid = 100;

  final bool autoExitOnStdinClose;
  final StreamController<List<int>> stdoutController = StreamController<List<int>>();
  final StreamController<List<int>> stderrController = StreamController<List<int>>();
  final StreamController<void> _frameChanged = StreamController<void>.broadcast();
  final Completer<int> _exit = Completer<int>();
  final List<Map<String, dynamic>> frames = <Map<String, dynamic>>[];
  late final StreamController<List<int>> _stdinController;
  late final StreamSubscription<String> _stdinSubscription;
  late final IOSink _stdin;
  bool stdinClosed = false;

  @override
  final int pid = _nextPid++;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  ProcessIdentity get identity => throw UnimplementedError();

  @override
  Stream<List<int>> get stderr => stderrController.stream;

  @override
  IOSink get stdin => _stdin;

  @override
  Stream<List<int>> get stdout => stdoutController.stream;

  void send(Map<String, dynamic> frame) {
    stdoutController.add(utf8.encode("${jsonEncode(frame)}\n"));
  }

  void completeExit(int code) {
    if (_exit.isCompleted) return;
    _exit.complete(code);
    unawaited(stdoutController.close());
    unawaited(stderrController.close());
    unawaited(_stdinSubscription.cancel());
    unawaited(_frameChanged.close());
  }

  Future<void> waitForFrames(int count) async {
    while (frames.length < count) {
      await _frameChanged.stream.first;
    }
  }
}
