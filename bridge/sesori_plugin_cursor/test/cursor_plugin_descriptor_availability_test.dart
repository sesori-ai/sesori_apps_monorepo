import "dart:async";
import "dart:convert";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:cursor_plugin/cursor_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("CursorPluginDescriptor.inspectSetup", () {
    const stateDirectory = "/state";
    const config = PluginConfig(
      values: {
        CursorPluginDescriptor.binOption: "cursor-agent",
        CursorPluginDescriptor.apiEndpointOption: null,
      },
    );

    test("tracks the installer target separately from the compatibility floor", () {
      expect(CursorPluginDescriptor.minVersion, "2026.07.16");
      expect(CursorPluginDescriptor.targetVersion, "2026.07.20-8cc9c0b");
    });

    test("reports ready after version and read-only authentication probes", () async {
      final processes = _ProbeProcessService(
        processSequence: [
          _ProbeProcess(
            pid: 1,
            stdoutBytes: utf8.encode("${CursorPluginDescriptor.targetVersion}\n"),
            exitCode: Future<int>.value(0),
          ),
          _ProbeProcess(
            pid: 2,
            stdoutBytes: utf8.encode("Authenticated\n"),
            exitCode: Future<int>.value(0),
          ),
        ],
      );

      final result = await const CursorPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, const PluginSetupReady());
      expect(processes.spawnedExecutables, ["cursor-agent", "cursor-agent"]);
      expect(processes.spawnedArguments, [
        const ["--version"],
        const ["status"],
      ]);
    });

    test("logs the successful runtime probe at the probe boundary", () async {
      final processes = _ProbeProcessService(
        processSequence: [
          _ProbeProcess(
            pid: 10,
            stdoutBytes: utf8.encode("${CursorPluginDescriptor.targetVersion}\n"),
            exitCode: Future<int>.value(0),
          ),
          _ProbeProcess(
            pid: 11,
            stdoutBytes: utf8.encode("Authenticated\n"),
            exitCode: Future<int>.value(0),
          ),
        ],
      );
      final stderrLines = <String>[];
      final previousLogLevel = Log.level;
      try {
        Log.level = LogLevel.debug;
        await IOOverrides.runZoned(
          () async {
            const descriptor = CursorPluginDescriptor();
            expect(
              await descriptor.inspectSetup(
                config: config,
                processes: processes,
                environment: const <String, String>{},
                stateDirectory: stateDirectory,
              ),
              const PluginSetupReady(),
            );
          },
          stderr: () => _CapturingStdout(stderrLines),
        );
      } finally {
        Log.level = previousLogLevel;
      }

      expect(
        stderrLines.where((line) => line.contains("[cursor] available:")),
        hasLength(1),
      );
      expect(processes.spawnedArguments, [
        const ["--version"],
        const ["status"],
      ]);
    });

    test("reports a non-provisionable missing runtime", () async {
      final processes = _ProbeProcessService(
        spawnError: const ProcessException("cursor-agent", ["--version"], "missing", 2),
      );

      final result = await const CursorPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupRuntimeMissing>());
    });

    test("reports an outdated runtime without retaining version probe text", () async {
      final processes = _ProbeProcessService(
        process: _ProbeProcess(
          pid: 12,
          stdoutBytes: utf8.encode("2025.01.01 account-secret-output\n"),
          exitCode: Future<int>.value(0),
        ),
      );

      final result = await const CursorPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupUnavailable>());
      expect(result.actionHint, isNot(contains("account-secret-output")));
      expect(processes.spawnedArguments, [
        const ["--version"],
      ]);
    });

    test("reports unknown for an exit-zero unrecognized version", () async {
      final processes = _ProbeProcessService(
        process: _ProbeProcess(
          pid: 13,
          stdoutBytes: utf8.encode("future-version-format\n"),
          exitCode: Future<int>.value(0),
        ),
      );

      final result = await const CursorPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupUnknown>());
    });

    test("reports unknown when '--version' exits non-zero", () async {
      final processes = _ProbeProcessService(
        process: _ProbeProcess(pid: 14, stdoutBytes: const <int>[], exitCode: Future<int>.value(1)),
      );

      final result = await const CursorPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupUnknown>());
    });

    test("reports unknown and force-kills a hung version probe", () async {
      final processes = _ProbeProcessService(
        process: _ProbeProcess(pid: 15, stdoutBytes: const <int>[], exitCode: Completer<int>().future),
      );
      const descriptor = CursorPluginDescriptor(versionProbeTimeout: Duration(milliseconds: 20));

      final result = await descriptor.inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupUnknown>());
      expect(processes.forceSignals, equals(<int>[15]));
    });

    test("reports authentication required without starting a login flow", () async {
      final processes = _ProbeProcessService(
        processSequence: [
          _ProbeProcess(
            pid: 3,
            stdoutBytes: utf8.encode("2026.07.16\n"),
            exitCode: Future<int>.value(0),
          ),
          _ProbeProcess(
            pid: 4,
            stdoutBytes: utf8.encode("Not authenticated\n"),
            exitCode: Future<int>.value(1),
          ),
        ],
      );

      final result = await const CursorPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupAuthenticationRequired>());
      expect(processes.spawnedArguments, [
        const ["--version"],
        const ["status"],
      ]);
      expect(processes.spawnedArguments.expand((arguments) => arguments), isNot(contains("login")));
    });

    test("reports unknown without exposing ambiguous status output", () async {
      final processes = _ProbeProcessService(
        processSequence: [
          _ProbeProcess(
            pid: 5,
            stdoutBytes: utf8.encode("2026.07.16\n"),
            exitCode: Future<int>.value(0),
          ),
          _ProbeProcess(
            pid: 6,
            stdoutBytes: utf8.encode("account-secret-output\n"),
            exitCode: Future<int>.value(0),
          ),
        ],
      );

      final result = await const CursorPluginDescriptor().inspectSetup(
        config: config,
        processes: processes,
        environment: const <String, String>{},
        stateDirectory: stateDirectory,
      );

      expect(result, isA<PluginSetupUnknown>());
      expect(result.actionHint, isNot(contains("account-secret-output")));
    });
  });

  group("CursorPluginDescriptor.start", () {
    test("does not probe persisted sessions before startup reconciliation", () async {
      final spawnedAcpProcesses = <FakeAcpProcess>[];
      final handledFrameIds = <FakeAcpProcess, Set<Object?>>{};
      var responding = true;
      final descriptor = CursorPluginDescriptor(
        buildPlugin:
            ({
              required String binaryPath,
              required String launchDirectory,
              required String? apiEndpoint,
              required AcpProcessFactory processFactory,
              required CursorSessionCleanupService sessionCleanupService,
            }) {
              return CursorPlugin(
                binaryPath: binaryPath,
                launchDirectory: launchDirectory,
                apiEndpoint: apiEndpoint,
                processFactory: (_) async {
                  final process = FakeAcpProcess();
                  spawnedAcpProcesses.add(process);
                  return process;
                },
                sessionCleanupService: sessionCleanupService,
              );
            },
      );
      final responsePump = () async {
        while (responding) {
          for (final process in spawnedAcpProcesses) {
            for (final frame in process.written) {
              final id = frame["id"];
              final processFrameIds = handledFrameIds.putIfAbsent(
                process,
                () => <Object?>{},
              );
              if (id == null || !processFrameIds.add(id)) continue;
              switch (frame["method"]) {
                case "initialize":
                  process.emit({
                    "jsonrpc": "2.0",
                    "id": id,
                    "result": const {
                      "protocolVersion": 1,
                      "agentCapabilities": <String, dynamic>{},
                      "authMethods": <Object?>[],
                    },
                  });
                case "cursor/list_available_models":
                  process.emit({
                    "jsonrpc": "2.0",
                    "id": id,
                    "result": const {"models": <Object?>[]},
                  });
              }
            }
          }
          await Future<void>.delayed(Duration.zero);
        }
      }();

      final plugin = await descriptor.start(
        _StartPluginHost(
          processes: _ProbeProcessService(
            spawnError: StateError("injected plugin must own the test process"),
          ),
        ),
      );
      responding = false;
      await responsePump;

      expect(
        spawnedAcpProcesses,
        hasLength(1),
        reason: "descriptor startup must only initialize the live ACP process",
      );

      await plugin.shutdown(budget: null);
      for (final process in spawnedAcpProcesses) {
        await process.close();
      }
    });
  });
}

class _StartPluginHost implements PluginHost {
  _StartPluginHost({required this.processes});

  @override
  final HostProcessService processes;

  @override
  PluginConfig get config => const PluginConfig(
    values: {
      CursorPluginDescriptor.binOption: "cursor-agent",
      CursorPluginDescriptor.apiEndpointOption: null,
    },
  );

  @override
  Map<String, String> get environment => const {"HOME": "/tmp"};

  @override
  ServerClock get clock => const ServerClock();

  @override
  StartAbortSignal get startAborted => StartAbortSignal.never;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A [HostProcessService] that either throws on [spawn] (to simulate ENOENT) or
/// returns a single canned [_ProbeProcess]. Records the spawn arguments and any
/// force-kill it is asked to deliver.
class _ProbeProcessService implements HostProcessService {
  _ProbeProcessService({this.spawnError, this.process, List<_ProbeProcess>? processSequence})
    : _processSequence = processSequence;

  final Object? spawnError;
  final _ProbeProcess? process;
  final List<_ProbeProcess>? _processSequence;
  int _nextProcess = 0;
  final List<String> spawnedExecutables = <String>[];
  final List<List<String>> spawnedArguments = <List<String>>[];
  final List<int> forceSignals = <int>[];

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) async {
    spawnedExecutables.add(executable);
    spawnedArguments.add(List<String>.from(arguments));
    final error = spawnError;
    if (error != null) {
      throw error;
    }
    final processSequence = _processSequence;
    if (processSequence != null) {
      return processSequence[_nextProcess++];
    }
    return process!;
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => null;

  @override
  Future<SignalResult> signalGraceful({required int pid}) async => _signal(pid);

  @override
  Future<SignalResult> signalForce({required int pid}) async {
    forceSignals.add(pid);
    return _signal(pid);
  }

  SignalResult _signal(int pid) => SignalResult(
    pid: pid,
    requestedSignal: ShutdownSignal.force,
    deliveredSignal: ProcessSignal.sigkill,
    wasRequested: true,
    attemptedAt: DateTime.utc(2026, 6, 1),
  );
}

/// A canned [SpawnedProcess] with a fixed stdout payload and a caller-supplied
/// [exitCode] future (which may never complete, to simulate a hang).
class _ProbeProcess implements SpawnedProcess {
  _ProbeProcess({required this.pid, required List<int> stdoutBytes, required Future<int> exitCode})
    : _stdoutBytes = stdoutBytes,
      _exitCode = exitCode;

  @override
  final int pid;

  final List<int> _stdoutBytes;
  final Future<int> _exitCode;

  @override
  Future<int> get exitCode => _exitCode;

  @override
  Stream<List<int>> get stdout => Stream<List<int>>.value(_stdoutBytes);

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  ProcessIdentity get identity => throw UnimplementedError();
}

class _CapturingStdout implements Stdout {
  _CapturingStdout(this.lines);

  final List<String> lines;

  @override
  void writeln([Object? object = ""]) {
    lines.add(object.toString());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
