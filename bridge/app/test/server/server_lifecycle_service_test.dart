import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/server/server_health_config.dart";
import "package:sesori_bridge/src/server/server_lifecycle_service.dart";
import "package:test/test.dart";

void main() {
  group("ServerLifecycleService", () {
    test("restart in managed mode stops old process starts new process and waits until ready", () async {
      final readyServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      readyServer.listen((request) async {
        request.response.statusCode = 200;
        await request.response.close();
      });

      final oldProcess = _FakeProcess(exitCodeOnKill: 7);
      final service = ServerLifecycleService(
        config: ServerHealthConfig(
          serverURL: "http://127.0.0.1:${readyServer.port}",
          password: "password",
          binaryPath: "/usr/bin/true",
          isManaged: true,
        ),
        initialProcess: oldProcess,
      );

      try {
        await service.restart();

        expect(oldProcess.killCallCount, equals(1));
      } finally {
        await readyServer.close(force: true);
        await service.stop();
      }
    });

    test("restart in unmanaged mode is a no-op", () async {
      final process = _FakeProcess(exitCodeOnKill: 0);
      final service = ServerLifecycleService(
        config: const ServerHealthConfig(
          serverURL: "http://127.0.0.1:4096",
          password: "password",
          binaryPath: "opencode",
          isManaged: false,
        ),
        initialProcess: process,
      );

      await service.restart();

      expect(process.killCallCount, equals(0));
    });

    test("stop is idempotent", () async {
      final process = _FakeProcess(exitCodeOnKill: 0);
      final service = ServerLifecycleService(
        config: const ServerHealthConfig(
          serverURL: "http://127.0.0.1:4096",
          password: "password",
          binaryPath: "opencode",
          isManaged: true,
        ),
        initialProcess: process,
      );

      await service.stop();
      await service.stop();

      expect(process.killCallCount, equals(1));
    });

    test("stop on null process is a no-op", () async {
      final service = ServerLifecycleService(
        config: const ServerHealthConfig(
          serverURL: "http://127.0.0.1:4096",
          password: "password",
          binaryPath: "opencode",
          isManaged: true,
        ),
        initialProcess: null,
      );

      await service.stop();
      await service.stop();
    });

    test("processExitEvents emits when the process exits", () async {
      final process = _FakeProcess();
      final service = ServerLifecycleService(
        config: const ServerHealthConfig(
          serverURL: "http://127.0.0.1:4096",
          password: "password",
          binaryPath: "opencode",
          isManaged: true,
        ),
        initialProcess: process,
      );

      final exitCodeFuture = service.processExitEvents.first;
      process.completeExit(23);

      expect(await exitCodeFuture, equals(23));
    });
  });
}

class _FakeProcess implements Process {
  final Completer<int> _exitCodeCompleter = Completer<int>();
  final int? exitCodeOnKill;
  int killCallCount = 0;

  _FakeProcess({this.exitCodeOnKill});

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  void completeExit(int code) {
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(code);
    }
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killCallCount++;
    if (exitCodeOnKill case final code?) {
      completeExit(code);
    }
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}
