import "dart:async";
import "dart:convert";
import "dart:io";

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

    test("reports ready after version and read-only authentication probes", () async {
      final processes = _ProbeProcessService(
        processSequence: [
          _ProbeProcess(
            pid: 1,
            stdoutBytes: utf8.encode("2026.07.20-8cc9c0b\n"),
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

    test("reports authentication required without starting a login flow", () async {
      final processes = _ProbeProcessService(
        processSequence: [
          _ProbeProcess(
            pid: 3,
            stdoutBytes: utf8.encode("2026.07.20\n"),
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
            stdoutBytes: utf8.encode("2026.07.20\n"),
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

  group("CursorPluginDescriptor.checkAvailability", () {
    // Keyed by the bare local option names (the mapper stores values unprefixed;
    // only the public CLI flag is namespaced to `--cursor-bin`).
    const config = PluginConfig(
      values: {
        CursorPluginDescriptor.binOption: "cursor-agent",
        CursorPluginDescriptor.apiEndpointOption: null,
      },
    );

    test("reports available when '<bin> --version' exits 0 with a recent build", () async {
      final processes = _ProbeProcessService(
        process: _ProbeProcess(
          pid: 4242,
          stdoutBytes: utf8.encode("2026.07.20-8cc9c0b\n"),
          exitCode: Future<int>.value(0),
        ),
      );

      final result = await const CursorPluginDescriptor().checkAvailability(
        config: config,
        processes: processes,
        environment: const <String, String>{"PATH": "/usr/bin"},
      );

      expect(result, isA<PluginAvailable>());
      // The probe runs exactly `<bin> --version`.
      expect(processes.spawnedExecutables, equals(<String>["cursor-agent"]));
      expect(processes.spawnedArguments.single, equals(<String>["--version"]));
    });

    test("does not retain version probe text beyond the parsed CalVer", () async {
      final processes = _ProbeProcessService(
        process: _ProbeProcess(
          pid: 5,
          stdoutBytes: utf8.encode("2025.01.01 account-secret-output\n"),
          exitCode: Future<int>.value(0),
        ),
      );

      final availability = await const CursorPluginDescriptor().checkAvailability(
        config: config,
        processes: processes,
        environment: const <String, String>{},
      );

      expect(availability, isA<PluginUnavailable>());
      expect((availability as PluginUnavailable).message, contains("2025.01.01"));
      expect(availability.message, isNot(contains("account-secret-output")));
    });

    test("preserves explicit startup for an exit-zero unrecognized version", () async {
      final processes = _ProbeProcessService(
        process: _ProbeProcess(
          pid: 4243,
          stdoutBytes: utf8.encode("future-version-format\n"),
          exitCode: Future<int>.value(0),
        ),
      );

      final result = await const CursorPluginDescriptor().checkAvailability(
        config: config,
        processes: processes,
        environment: const <String, String>{},
      );

      expect(result, isA<PluginAvailable>());
    });

    test("reports unavailable (outdated) when the build is below the minimum", () async {
      final processes = _ProbeProcessService(
        process: _ProbeProcess(
          pid: 7,
          stdoutBytes: utf8.encode("2026.05.28-09-00-00-deadbee\n"),
          exitCode: Future<int>.value(0),
        ),
      );

      final result = await const CursorPluginDescriptor().checkAvailability(
        config: config,
        processes: processes,
        environment: const <String, String>{},
      );

      expect(result, isA<PluginUnavailable>());
      final message = (result as PluginUnavailable).message;
      expect(message, contains("too old"));
      expect(message, contains(CursorPluginDescriptor.minVersion));
      expect(message, contains("cursor-agent update"));
    });

    test("reports unavailable (not installed) when the binary cannot be launched", () async {
      final processes = _ProbeProcessService(
        spawnError: const ProcessException("cursor-agent", ["--version"], "No such file or directory", 2),
      );

      final result = await const CursorPluginDescriptor().checkAvailability(
        config: config,
        processes: processes,
        environment: const <String, String>{},
      );

      expect(result, isA<PluginUnavailable>());
      final message = (result as PluginUnavailable).message;
      expect(message, contains("Cursor was not found"));
      expect(message, contains("cursor-agent --version"));
    });

    test("reports unavailable (not working) when '--version' exits non-zero", () async {
      final processes = _ProbeProcessService(
        process: _ProbeProcess(pid: 11, stdoutBytes: const <int>[], exitCode: Future<int>.value(1)),
      );

      final result = await const CursorPluginDescriptor().checkAvailability(
        config: config,
        processes: processes,
        environment: const <String, String>{},
      );

      expect(result, isA<PluginUnavailable>());
      expect((result as PluginUnavailable).message, contains("did not respond"));
    });

    test("reports unavailable and force-kills the probe when '--version' hangs", () async {
      final processes = _ProbeProcessService(
        // exitCode never completes -> the probe must time out.
        process: _ProbeProcess(pid: 99, stdoutBytes: const <int>[], exitCode: Completer<int>().future),
      );
      const descriptor = CursorPluginDescriptor(versionProbeTimeout: Duration(milliseconds: 20));

      final result = await descriptor.checkAvailability(
        config: config,
        processes: processes,
        environment: const <String, String>{},
      );

      expect(result, isA<PluginUnavailable>());
      expect((result as PluginUnavailable).message, contains("did not respond"));
      // The hung probe is reaped so it cannot linger.
      expect(processes.forceSignals, equals(<int>[99]));
    });
  });
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
