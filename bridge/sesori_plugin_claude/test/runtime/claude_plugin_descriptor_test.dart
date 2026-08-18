import "dart:async";
import "dart:convert";
import "dart:io";

import "package:claude_plugin/claude_plugin.dart";
import "package:claude_plugin/claude_testing.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const config = PluginConfig(values: {ClaudePluginDescriptor.binOption: "claude"});

  group("ClaudePluginDescriptor.inspectSetup", () {
    test("declares the Claude plugin contract and bare bin option", () {
      const descriptor = ClaudePluginDescriptor();
      expect(descriptor.id, "claude");
      expect(descriptor.displayName, "Claude Code");
      expect(descriptor.projectOwnership, PluginProjectOwnership.bridgeDerived);
      expect(descriptor.sessionOptionsScope, PluginSessionOptionsScope.plugin);
      expect(descriptor.supportsPromptAttachments, isTrue);
      expect(descriptor.options.single.name, "bin");
      expect(ClaudePluginDescriptor.minVersion, "2.1.221");
    });

    test("reports ready after ordered version and typed auth probes", () async {
      final processes = _ProcessService([
        _ProbeProcess(stdoutText: "2.1.226 (Claude Code)\n", exitCode: Future.value(0)),
        _ProbeProcess(
          stdoutText: jsonEncode({
            "loggedIn": true,
            "email": "private@example.com",
            "orgName": "Private Org",
          }),
          exitCode: Future.value(0),
        ),
      ]);

      final status = await const ClaudePluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const {"PATH": "/bin"},
        stateDirectory: "/state",
      );

      expect(status, const PluginSetupReady.versioned(runtimeVersion: "2.1.226"));
      expect(processes.arguments, [
        const ["--version"],
        const ["auth", "status"],
      ]);
      expect(processes.environments, [
        const {"PATH": "/bin"},
        const {"PATH": "/bin"},
      ]);
    });

    test("reports runtime missing when the version process cannot spawn", () async {
      final status = await const ClaudePluginDescriptor().inspectSetup(
        config: config,
        processes: _ProcessService([
          const ProcessException("claude", ["--version"], "missing", 2),
        ]),
        environment: const {},
        stateDirectory: "/state",
      );

      _expectNonReady<PluginSetupRuntimeMissing>(status);
    });

    test("reports unavailable and skips auth for an outdated runtime", () async {
      final processes = _ProcessService([
        _ProbeProcess(stdoutText: "2.1.220 (Claude Code)\n", exitCode: Future.value(0)),
      ]);

      final status = await const ClaudePluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const {},
        stateDirectory: "/state",
      );

      _expectNonReady<PluginSetupUnavailable>(status);
      expect(processes.arguments, [
        const ["--version"],
      ]);
    });

    test("reports authentication required from loggedIn false only", () async {
      final processes = _ProcessService([
        _ProbeProcess(stdoutText: "2.1.221 (Claude Code)\n", exitCode: Future.value(0)),
        _ProbeProcess(
          stdoutText: '{"loggedIn":false,"email":"private@example.com"}',
          exitCode: Future.value(1),
        ),
      ]);

      final status = await const ClaudePluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const {},
        stateDirectory: "/state",
      );

      _expectNonReady<PluginSetupAuthenticationRequired>(status);
      expect(status.runtimeVersion, "2.1.221");
      expect(status.actionHint, isNot(contains("private@example.com")));
    });

    test("reports unknown for malformed auth without exposing its payload", () async {
      final processes = _ProcessService([
        _ProbeProcess(stdoutText: "2.1.221 (Claude Code)\n", exitCode: Future.value(0)),
        _ProbeProcess(stdoutText: "private-account-output", exitCode: Future.value(0)),
      ]);

      final status = await const ClaudePluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const {},
        stateDirectory: "/state",
      );

      _expectNonReady<PluginSetupUnknown>(status);
      expect(status.runtimeVersion, "2.1.221");
      expect(status.actionHint, isNot(contains("private-account-output")));
    });

    test("bounds a hung version probe and force-kills it", () async {
      final process = _ProbeProcess(stdoutText: "", exitCode: Completer<int>().future);
      final processes = _ProcessService([process]);

      final status =
          await const ClaudePluginDescriptor(
            probeTimeout: Duration(milliseconds: 10),
          ).inspectSetup(
            config: config,
            processes: processes,
            environment: const {},
            stateDirectory: "/state",
          );

      _expectNonReady<PluginSetupUnknown>(status);
      expect(processes.forceSignaledPids, [process.pid]);
    });
  });

  group("ClaudePluginDescriptor.start", () {
    test("rejects an entry abort without constructing a plugin", () async {
      var constructed = false;
      final descriptor = ClaudePluginDescriptor(
        buildBridgePlugin:
            ({
              required plugin,
              required sessions,
              required processFactory,
              required clock,
              required statusDebounce,
            }) {
              constructed = true;
              return ClaudeBridgePlugin(
                plugin: plugin,
                sessions: sessions,
                processFactory: processFactory,
                clock: clock,
                statusDebounce: statusDebounce,
              );
            },
      );

      await expectLater(
        descriptor.start(_PluginHost(startAborted: _AlwaysAbortedSignal(), processes: _ProcessService([]))),
        throwsA(isA<PluginStartAbortedException>()),
      );
      expect(constructed, isFalse);
    });

    test("rolls back through shutdown on a post-construction abort", () async {
      ClaudeBridgePlugin? constructed;
      final descriptor = ClaudePluginDescriptor(
        buildBridgePlugin:
            ({
              required plugin,
              required sessions,
              required processFactory,
              required clock,
              required statusDebounce,
            }) {
              return constructed = ClaudeBridgePlugin(
                plugin: plugin,
                sessions: sessions,
                processFactory: processFactory,
                clock: clock,
                statusDebounce: statusDebounce,
              );
            },
      );

      await expectLater(
        descriptor.start(_PluginHost(startAborted: _AbortOnSecondCheck(), processes: _ProcessService([]))),
        throwsA(isA<PluginStartAbortedException>()),
      );
      expect(constructed?.currentStatus, const PluginStopped());
    });

    test("uses host spawning, degrades on spawn failure, and readies on retry", () async {
      final liveProcess = _ProbeProcess(
        stdoutText: "",
        exitCode: Completer<int>().future,
        keepStdoutOpen: true,
      );
      final processes = _ProcessService([
        const ProcessException("claude", [], "missing", 2),
        liveProcess,
      ])..answerClaudeInitialize = true;
      final plugin = await const ClaudePluginDescriptor(
        statusDebounce: Duration.zero,
      ).start(_PluginHost(startAborted: StartAbortSignal.never, processes: processes));
      addTearDown(() async {
        await plugin.shutdown(budget: null);
        await liveProcess.close();
      });

      expect(plugin.currentStatus, const PluginReady());
      await expectLater(
        plugin.api.getSessionOptions(
          projectId: "/tmp/project",
          discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
        ),
        throwsA(isA<ProcessException>()),
      );
      await _pump();
      expect(plugin.currentStatus, isA<PluginDegraded>());
      final degraded = plugin.currentStatus as PluginDegraded;
      expect(degraded.recoverable, isTrue);
      expect(degraded.userActionHint, isNotEmpty);

      await plugin.api.getSessionOptions(
        projectId: "/tmp/project",
        discoveryMode: PluginSessionOptionsDiscoveryMode.reuse,
      );
      expect(plugin.currentStatus, const PluginReady());
      expect(processes.runInShellValues, [Platform.isWindows, Platform.isWindows]);
      expect(processes.workingDirectories, everyElement(Directory.systemTemp.path));
      expect(processes.environments, everyElement(containsPair("HOME", "/Users/test")));

      liveProcess.completeExit(1);
      await _pump();
      expect(plugin.currentStatus, const PluginReady());
      expect(plugin.describe().details, {"transport": "claude-stream-json"});
    });
  });
}

void _expectNonReady<T extends PluginSetupStatus>(PluginSetupStatus status) {
  expect(status, isA<T>());
  expect(status, isNot(isA<PluginSetupNotInspected>()));
  expect(status.actionHint, isNotEmpty);
}

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _PluginHost({
  @override required final StartAbortSignal startAborted,
  @override required final HostProcessService processes,
}) implements PluginHost {
  @override
  PluginConfig get config => const PluginConfig(values: {ClaudePluginDescriptor.binOption: "claude"});

  @override
  Map<String, String> get environment => const {
    "CLAUDE_CONFIG_DIR": "/tmp/claude-descriptor-test",
    "HOME": "/Users/test",
  };

  @override
  String get stateDirectory => Directory.systemTemp.path;

  @override
  ServerClock get clock => const ServerClock();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _AlwaysAbortedSignal() implements StartAbortSignal {
  @override
  bool get isAborted => true;

  @override
  Future<void> get whenAborted => Future.value();
}

final class _AbortOnSecondCheck() implements StartAbortSignal {
  int checks = 0;

  @override
  bool get isAborted => ++checks >= 2;

  @override
  Future<void> get whenAborted => Completer<void>().future;
}

final class _ProcessService(final List<Object> _outcomes) implements HostProcessService {
  final List<List<String>> arguments = [];
  final List<Map<String, String>?> environments = [];
  final List<bool> runInShellValues = [];
  final List<String?> workingDirectories = [];
  final List<int> forceSignaledPids = [];
  bool answerClaudeInitialize = false;
  var _index = 0;

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) async {
    this.arguments.add(List.unmodifiable(arguments));
    environments.add(environment == null ? null : Map.unmodifiable(environment));
    runInShellValues.add(runInShell);
    workingDirectories.add(workingDirectory);
    final outcome = _outcomes[_index++];
    if (outcome is! SpawnedProcess) throw outcome;
    if (answerClaudeInitialize && outcome is _ProbeProcess) {
      unawaited(outcome.answerInitialize());
    }
    return outcome;
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => null;

  @override
  Future<SignalResult> signalGraceful({required int pid}) async {
    final outcome = _outcomes.whereType<_ProbeProcess>().where((process) => process.pid == pid).firstOrNull;
    outcome?.completeExit(-15);
    return _signal(pid);
  }

  @override
  Future<SignalResult> signalForce({required int pid}) async {
    forceSignaledPids.add(pid);
    final outcome = _outcomes.whereType<_ProbeProcess>().where((process) => process.pid == pid).firstOrNull;
    outcome?.completeExit(-9);
    return _signal(pid);
  }

  SignalResult _signal(int pid) => SignalResult(
    pid: pid,
    requestedSignal: ShutdownSignal.force,
    deliveredSignal: ProcessSignal.sigkill,
    wasRequested: true,
    attemptedAt: DateTime.utc(2026, 8, 11),
  );
}

final class _ProbeProcess({
  required String stdoutText,
  required Future<int> exitCode,
  bool keepStdoutOpen = false,
}) implements SpawnedProcess {
  this : pid = _nextPid++, _stdout = StreamController<List<int>>(), _stdin = CapturingIOSink() {
    if (stdoutText.isNotEmpty) _stdout.add(utf8.encode(stdoutText));
    if (!keepStdoutOpen) unawaited(_stdout.close());
    unawaited(exitCode.then(completeExit));
  }

  static var _nextPid = 100;

  @override
  final int pid;

  final StreamController<List<int>> _stdout;
  final Completer<int> _exit = Completer<int>();
  final CapturingIOSink _stdin;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  IOSink get stdin => _stdin;

  @override
  ProcessIdentity get identity => throw UnimplementedError();

  void completeExit(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
  }

  Future<void> answerInitialize() async {
    for (var attempt = 0; attempt < 100; attempt++) {
      final initialize = _stdin.frames.where((frame) => frame["type"] == "control_request").firstOrNull;
      if (initialize != null) {
        final requestId = initialize["request_id"]! as String;
        _stdout.add(
          utf8.encode(
            '${jsonEncode({
              "type": "control_response",
              "response": {
                "subtype": "success",
                "request_id": requestId,
                "response": {
                  "commands": <Object?>[],
                  "models": <Object?>[],
                },
              },
            })}\n',
          ),
        );
        return;
      }
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> close() async {
    if (!_stdout.isClosed) await _stdout.close();
  }
}
