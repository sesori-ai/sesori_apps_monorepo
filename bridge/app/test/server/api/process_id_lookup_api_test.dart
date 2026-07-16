import "dart:async";
import "dart:io";

import "package:sesori_bridge/src/bridge/foundation/process_runner.dart";
import "package:sesori_bridge/src/server/api/process_id_lookup_api.dart";
import "package:test/test.dart";

void main() {
  group("ProcessIdLookupApi (POSIX)", () {
    test("exact-matches the executable name and parses process ids", () async {
      final runner = _RecordingProcessRunner(stdout: "123\n456\n");
      final api = ProcessIdLookupApi.forPlatform(
        isWindows: false,
        processRunner: runner,
      );

      final processIds = await api.listProcessIdsByExecutableName(
        executableName: "sesori-bridge",
      );

      expect(processIds, equals(<int>[123, 456]));
      expect(runner.executable, equals("pgrep"));
      expect(runner.arguments, equals(<String>["-x", "sesori-bridge"]));
      expect(runner.environment, equals(const <String, String>{"LC_ALL": "C"}));
    });

    test("returns an empty list when pgrep finds no matches", () async {
      final api = ProcessIdLookupApi.forPlatform(
        isWindows: false,
        processRunner: _RecordingProcessRunner(exitCode: 1),
      );

      expect(
        await api.listProcessIdsByExecutableName(executableName: "sesori-bridge"),
        isEmpty,
      );
    });

    test("throws when pgrep fails", () async {
      final api = ProcessIdLookupApi.forPlatform(
        isWindows: false,
        processRunner: _RecordingProcessRunner(
          exitCode: 2,
          stderr: "invalid pattern",
        ),
      );

      await expectLater(
        api.listProcessIdsByExecutableName(executableName: "sesori-bridge"),
        throwsA(isA<ProcessException>()),
      );
    });

    test("rejects malformed or non-positive process ids", () async {
      for (final stdout in <String>["not-a-pid\n", "0\n", "-1\n"]) {
        final api = ProcessIdLookupApi.forPlatform(
          isWindows: false,
          processRunner: _RecordingProcessRunner(stdout: stdout),
        );

        await expectLater(
          api.listProcessIdsByExecutableName(executableName: "sesori-bridge"),
          throwsA(isA<FormatException>()),
        );
      }
    });
  });

  group("ProcessIdLookupApi (Windows)", () {
    test("filters tasklist by image name and parses process ids", () async {
      final runner = _RecordingProcessRunner(
        stdout:
            '"sesori-bridge.exe","321","Console","1","12,345 K"\r\n'
            '"sesori-bridge.exe","654","Console","1","98,765 K"\r\n',
      );
      final api = ProcessIdLookupApi.forPlatform(
        isWindows: true,
        processRunner: runner,
      );

      final processIds = await api.listProcessIdsByExecutableName(
        executableName: "sesori-bridge",
      );

      expect(processIds, equals(<int>[321, 654]));
      expect(runner.executable, equals("tasklist"));
      expect(
        runner.arguments,
        equals(<String>[
          "/FO",
          "CSV",
          "/NH",
          "/FI",
          "IMAGENAME eq sesori-bridge.exe",
        ]),
      );
      expect(runner.environment, isNull);
    });

    test("returns an empty list when tasklist finds no matches", () async {
      final api = ProcessIdLookupApi.forPlatform(
        isWindows: true,
        processRunner: _RecordingProcessRunner(
          stdout: "INFO: No tasks are running which match the specified criteria.\r\n",
        ),
      );

      expect(
        await api.listProcessIdsByExecutableName(executableName: "sesori-bridge"),
        isEmpty,
      );
    });

    test("ignores malformed tasklist rows", () async {
      final api = ProcessIdLookupApi.forPlatform(
        isWindows: true,
        processRunner: _RecordingProcessRunner(
          stdout:
              '"sesori-bridge.exe","not-a-pid"\r\n'
              '"sesori-bridge.exe","0"\r\n',
        ),
      );

      expect(
        await api.listProcessIdsByExecutableName(executableName: "sesori-bridge"),
        isEmpty,
      );
    });

    test("throws when tasklist fails", () async {
      final api = ProcessIdLookupApi.forPlatform(
        isWindows: true,
        processRunner: _RecordingProcessRunner(exitCode: 1, stderr: "boom"),
      );

      await expectLater(
        api.listProcessIdsByExecutableName(executableName: "sesori-bridge"),
        throwsA(isA<ProcessException>()),
      );
    });
  });
}

class _RecordingProcessRunner implements ProcessRunner {
  _RecordingProcessRunner({this.exitCode = 0, this.stdout = "", this.stderr = ""});

  final int exitCode;
  final String stdout;
  final String stderr;
  String? executable;
  List<String>? arguments;
  Map<String, String>? environment;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    this.executable = executable;
    this.arguments = arguments;
    this.environment = environment;
    return ProcessResult(1, exitCode, stdout, stderr);
  }

  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) {
    throw UnimplementedError();
  }
}
