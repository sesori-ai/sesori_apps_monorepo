import "dart:async";
import "dart:convert";
import "dart:io";

import "package:claude_plugin/claude_plugin.dart";
import "package:sesori_plugin_interface/plugin_interface_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const String _url = "https://claude.com/cai/oauth/authorize?code=true&client_id=client&state=private-state";
const String _code = "private-code#private-state";

void main() {
  group("ClaudePastedCode", () {
    test("accepts one code and state pair", () {
      expect(ClaudePastedCode.tryParse(raw: _code)?.value, _code);
    });

    test("rejects every other shape", () {
      for (final raw in ["", "code", "#state", "code#", "a#b#c", "co de#state", "code#st\tate", "a#${"b" * 511}"]) {
        expect(ClaudePastedCode.tryParse(raw: raw), isNull, reason: raw);
      }
    });
  });

  group("ClaudeLoginOutputParser", () {
    const parser = ClaudeLoginOutputParser();

    test("reads the URL inside an OSC 8 hyperlink", () {
      final outcome = parser.parseLine(line: "If the browser didn't open, visit: \x1B]8;;$_url\x07$_url\x1B]8;;\x07");

      expect(
        outcome,
        isA<ClaudeLoginOutputUrl>().having((url) => url.authorizationUri, "authorizationUri", Uri.parse(_url)),
      );
    });

    test("ignores lines without an HTTPS token", () {
      for (final line in ["Opening browser to sign in…", "Paste code here if prompted > ", "Login successful."]) {
        expect(parser.parseLine(line: line), isA<ClaudeLoginOutputNone>(), reason: line);
      }
    });

    test("reports an oversized or unparsable token by length only", () {
      final oversized = "https://claude.com/${"a" * ClaudeLoginOutputParser.maxUrlLength}";
      for (final token in [oversized, "https://[::1", "https://:443/path"]) {
        expect(
          parser.parseLine(line: "visit: $token"),
          isA<ClaudeLoginOutputInvalidUrl>().having((invalid) => invalid.length, "length", token.length),
        );
      }
    });

    test("redacts escape sequences and URLs from diagnostic lines", () {
      expect(parser.redactLine(line: "\x1B[31mfailed\x1B[0m: see $_url now"), "failed: see <url> now");
    });
  });

  group("ClaudeAuthenticationService", () {
    test("publishes the URL from fragmented output, writes the code, and completes on exit 0", () async {
      final processes = _LoginProcesses();
      final operation = _operation(processes: processes);
      final events = <PluginAuthenticationPastedCodeEvent>[];
      final done = operation.events.forEach(events.add);
      final process = await processes.spawnedProcess();

      final output = utf8.encode(
        "Opening browser to sign in…\n"
        "If the browser didn't open, visit: \x1B]8;;$_url\x07$_url\x1B]8;;\x07\n"
        "Paste code here if prompted > ",
      );
      // Splits inside the ellipsis and inside the URL.
      process.emitStdout(bytes: output.sublist(0, 27));
      process.emitStdout(bytes: output.sublist(27, 80));
      process.emitStdout(bytes: output.sublist(80));
      await _until(condition: () => events.isNotEmpty);

      expect(
        events.single,
        isA<PluginAuthenticationPastedCodeChallenge>().having(
          (challenge) => challenge.authorizationUri,
          "authorizationUri",
          Uri.parse(_url),
        ),
      );

      await operation.submitCode(code: _code);
      expect(process.stdin.text, "$_code\n");
      process.exit(code: 0);
      await done;

      expect(events.last, isA<PluginAuthenticationCompleted>());
    });

    test("fails when the CLI exits before printing a URL", () async {
      final logs = await _logsOf(
        body: () async {
          final processes = _LoginProcesses();
          final done = _operation(processes: processes).events.toList();
          final process = await processes.spawnedProcess();

          process.emitStderr(text: "Error: login is disabled by policy, see $_url\n");
          await _pump();
          process.exit(code: 1);

          expect(await done, [isA<PluginAuthenticationFailed>()]);
        },
      );

      expect(logs, contains("exited with code 1 before printing a sign-in URL"));
      expect(logs, contains("Error: login is disabled by policy, see <url>"));
      expect(logs, isNot(contains("claude.com")));
    });

    test("fails at once on an unusable URL token and stops the CLI", () async {
      final processes = _LoginProcesses();
      final done = _operation(processes: processes).events.toList();
      final process = await processes.spawnedProcess();

      process.emitStdout(bytes: utf8.encode("visit: https://[::1\n"));

      expect(await done, [isA<PluginAuthenticationFailed>()]);
      expect(processes.gracefulSignals, [process.pid]);
    });

    test("stops the CLI when no URL appears within the URL budget", () async {
      final processes = _LoginProcesses();
      final done = _operation(processes: processes, urlBudget: const Duration(milliseconds: 20)).events.toList();
      final process = await processes.spawnedProcess();

      expect(await done, [isA<PluginAuthenticationFailed>()]);
      expect(processes.gracefulSignals, [process.pid]);
    });

    test("stops the CLI when the overall budget ends after the challenge", () async {
      final processes = _LoginProcesses();
      final done = _operation(processes: processes, overallBudget: const Duration(milliseconds: 200)).events.toList();
      final process = await processes.spawnedProcess();

      process.emitStdout(bytes: utf8.encode("visit: $_url\n"));

      expect(await done, [isA<PluginAuthenticationPastedCodeChallenge>(), isA<PluginAuthenticationFailed>()]);
      expect(processes.gracefulSignals, [process.pid]);
    });

    test("fails on a non-zero exit after the code and logs the redacted stderr written as it exits", () async {
      final logs = await _logsOf(
        body: () async {
          final processes = _LoginProcesses();
          final operation = _operation(processes: processes);
          final events = <PluginAuthenticationPastedCodeEvent>[];
          final done = operation.events.forEach(events.add);
          final process = await processes.spawnedProcess();
          process.emitStdout(bytes: utf8.encode("visit: $_url\n"));
          await _until(condition: () => events.isNotEmpty);

          await operation.submitCode(code: _code);
          // The exit is reported before its last stderr line arrives.
          process.reportExit(code: 1);
          await _pump();
          process.emitStderr(text: "OAuth error: invalid_grant, retry at $_url\n");
          process.exit(code: 1);
          await done;

          expect(events.last, isA<PluginAuthenticationFailed>());
        },
      );

      expect(logs, contains("exited with code 1"));
      expect(logs, contains("OAuth error: invalid_grant, retry at <url>"));
      expect(logs, isNot(contains("private-state")));
      expect(logs, isNot(contains("private-code")));
    });

    test("stops the CLI and cancels when aborted while waiting for the URL", () async {
      final processes = _LoginProcesses();
      final abort = StartAbortController();
      final done = _operation(processes: processes, aborted: abort.signal).events.toList();
      final process = await processes.spawnedProcess();

      abort.abort();

      await expectLater(done, throwsA(isA<PluginStartAbortedException>()));
      expect(processes.gracefulSignals, [process.pid]);
      // Signals leave the fake's pipes open, as a descendant holding them would.
      expect(process.hasListeners, isFalse);
    });

    test("stops the CLI and cancels when aborted during code submission", () async {
      final processes = _LoginProcesses();
      final abort = StartAbortController();
      final operation = _operation(processes: processes, aborted: abort.signal);
      final events = <PluginAuthenticationPastedCodeEvent>[];
      final done = operation.events.forEach(events.add);
      final process = await processes.spawnedProcess();
      process.emitStdout(bytes: utf8.encode("visit: $_url\n"));
      await _until(condition: () => events.isNotEmpty);
      final flush = Completer<void>();
      process.stdin.flushGate = flush.future;

      final submission = operation.submitCode(code: _code);
      abort.abort();

      await expectLater(done, throwsA(isA<PluginStartAbortedException>()));
      expect(processes.gracefulSignals, [process.pid]);
      flush.complete();
      await submission;
    });

    test("stops the CLI and fails the operation for a code of the wrong shape", () async {
      final logs = await _logsOf(
        body: () async {
          // The outcome must not depend on how the stopped CLI exits.
          final processes = _LoginProcesses()..gracefulExitCode = 0;
          final operation = _operation(processes: processes);
          final events = <PluginAuthenticationPastedCodeEvent>[];
          final done = operation.events.forEach(events.add);
          final process = await processes.spawnedProcess();
          process.emitStdout(bytes: utf8.encode("visit: $_url\n"));
          await _until(condition: () => events.isNotEmpty);

          await operation.submitCode(code: "private-code-without-state");
          await done;

          expect(events.last, isA<PluginAuthenticationFailed>());
          expect(processes.gracefulSignals, [process.pid]);
          expect(process.stdin.text, isEmpty);
        },
      );

      expect(logs, contains("not a code#state pair"));
      expect(logs, isNot(contains("private-code")));
    });

    test("forces a CLI that ignores the graceful stop", () async {
      final processes = _LoginProcesses()..gracefulExitCode = null;
      final done = _operation(
        processes: processes,
        urlBudget: const Duration(milliseconds: 20),
        killGrace: const Duration(milliseconds: 20),
      ).events.toList();
      final process = await processes.spawnedProcess();

      expect(await done, [isA<PluginAuthenticationFailed>()]);
      expect(processes.gracefulSignals, [process.pid]);
      expect(processes.forceSignals, [process.pid]);
    });

    test("fails when the CLI cannot be spawned", () async {
      final processes = _LoginProcesses()..spawnError = const ProcessException("claude", [], "missing", 2);

      expect(await _operation(processes: processes).events.toList(), [isA<PluginAuthenticationFailed>()]);
    });
  });
}

PluginAuthenticationPastedCodeOperation _operation({
  required _LoginProcesses processes,
  StartAbortSignal? aborted,
  Duration urlBudget = const Duration(seconds: 30),
  Duration overallBudget = const Duration(seconds: 30),
  Duration killGrace = const Duration(seconds: 5),
}) {
  final operation = ClaudeAuthenticationService(
    repository: ClaudeAuthenticationRepository(
      processFactory: HostClaudeProcessFactory(processes: processes, environment: const {"PATH": "/bin"}),
      binaryPath: "claude",
      workingDirectory: "/state",
      environment: ClaudeLoginEnvironment.overrides,
      killGrace: killGrace,
    ),
    aborted: aborted ?? StartAbortSignal.never,
    urlBudget: urlBudget,
    overallBudget: overallBudget,
  ).authenticate();
  if (operation is! PluginAuthenticationPastedCodeOperation) fail("Claude login must be a pasted-code operation");
  return operation;
}

Future<String> _logsOf({required Future<void> Function() body}) async {
  final logs = BufferingStdout();
  await IOOverrides.runZoned(body, stderr: () => logs);
  return logs.text;
}

Future<void> _pump() async {
  for (var turn = 0; turn < 10; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _until({required bool Function() condition}) async {
  for (var turn = 0; turn < 100; turn++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail("condition was not reached");
}

final class _LoginProcesses() implements HostProcessService {
  final List<_LoginProcess> spawned = [];
  final List<int> gracefulSignals = [];
  final List<int> forceSignals = [];

  /// The exit code a graceful signal reports, or null for a CLI that ignores it.
  int? gracefulExitCode = -15;
  Object? spawnError;

  Future<_LoginProcess> spawnedProcess() async {
    await _until(condition: () => spawned.isNotEmpty);
    return spawned.single;
  }

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
    required bool includeParentEnvironment,
  }) async {
    if (spawnError case final error?) throw error;
    final process = _LoginProcess(pid: 100 + spawned.length);
    spawned.add(process);
    return process;
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => null;

  @override
  Future<SignalResult> signalGraceful({required int pid}) async {
    gracefulSignals.add(pid);
    if (gracefulExitCode case final code?) _process(pid: pid).reportExit(code: code);
    return _signalResult(pid: pid);
  }

  @override
  Future<SignalResult> signalForce({required int pid}) async {
    forceSignals.add(pid);
    _process(pid: pid).reportExit(code: -9);
    return _signalResult(pid: pid);
  }

  _LoginProcess _process({required int pid}) => spawned.singleWhere((process) => process.pid == pid);

  SignalResult _signalResult({required int pid}) => SignalResult(
    pid: pid,
    requestedSignal: ShutdownSignal.graceful,
    deliveredSignal: ProcessSignal.sigterm,
    wasRequested: true,
    attemptedAt: DateTime.utc(2026, 9, 16),
  );
}

final class _LoginProcess({@override required final int pid}) implements SpawnedProcess {
  final StreamController<List<int>> _stdout = StreamController();
  final StreamController<List<int>> _stderr = StreamController();
  final Completer<int> _exit = Completer();

  @override
  final _StdinSink stdin = _StdinSink();

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  ProcessIdentity get identity => throw UnimplementedError();

  bool get hasListeners => _stdout.hasListener || _stderr.hasListener;

  void emitStdout({required List<int> bytes}) => _stdout.add(bytes);

  void emitStderr({required String text}) => _stderr.add(utf8.encode(text));

  /// Reports the exit code but leaves both pipes open.
  void reportExit({required int code}) {
    if (!_exit.isCompleted) _exit.complete(code);
  }

  void exit({required int code}) {
    reportExit(code: code);
    unawaited(_stdout.close());
    unawaited(_stderr.close());
  }
}

/// Keeps the raw bytes written to the CLI, so a test sees exactly one line.
final class _StdinSink() implements IOSink {
  final List<int> _bytes = [];
  Future<void>? flushGate;

  String get text => utf8.decode(_bytes);

  @override
  void add(List<int> data) => _bytes.addAll(data);

  @override
  Future<void> flush() => flushGate ?? Future<void>.value();

  @override
  Future<void> get done => Completer<void>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
