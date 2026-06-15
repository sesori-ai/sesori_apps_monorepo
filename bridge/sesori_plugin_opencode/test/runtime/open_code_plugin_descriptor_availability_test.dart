import "dart:async";
import "dart:convert";
import "dart:io";

import "package:opencode_plugin/src/runtime/open_code_plugin_descriptor.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("OpenCodePluginDescriptor.checkAvailability", () {
    const managedConfig = PluginConfig(
      values: {"no-auto-start": false, "port": null, "password": "", "opencode-bin": "opencode"},
    );

    test("attach mode (--no-auto-start) reports available without spawning a probe", () async {
      final processes = _ProbeProcessService(
        spawnError: StateError("spawn must not be called in attach mode"),
      );

      final result = await const OpenCodePluginDescriptor().checkAvailability(
        config: const PluginConfig(
          values: {"no-auto-start": true, "port": "4096", "password": "", "opencode-bin": "opencode"},
        ),
        processes: processes,
        environment: const <String, String>{},
      );

      expect(result, isA<PluginAvailable>());
      expect(processes.spawnedExecutables, isEmpty);
    });

    test("reports available when '<bin> --version' exits 0", () async {
      final processes = _ProbeProcessService(
        process: _ProbeProcess(pid: 4242, stdoutBytes: utf8.encode("opencode 0.5.0\n"), exitCode: Future<int>.value(0)),
      );

      final result = await const OpenCodePluginDescriptor().checkAvailability(
        config: managedConfig,
        processes: processes,
        environment: const <String, String>{"PATH": "/usr/bin"},
      );

      expect(result, isA<PluginAvailable>());
      // The probe runs exactly `<bin> --version`.
      expect(processes.spawnedExecutables, equals(<String>["opencode"]));
      expect(processes.spawnedArguments.single, equals(<String>["--version"]));
    });

    test("reports unavailable (not installed) when the binary cannot be launched", () async {
      final processes = _ProbeProcessService(
        spawnError: const ProcessException("opencode", ["--version"], "No such file or directory", 2),
      );

      final result = await const OpenCodePluginDescriptor().checkAvailability(
        config: managedConfig,
        processes: processes,
        environment: const <String, String>{},
      );

      expect(result, isA<PluginUnavailable>());
      final message = (result as PluginUnavailable).message;
      expect(message, contains("OpenCode was not found"));
      expect(message, contains("opencode --version"));
      expect(message, contains("https://opencode.ai/docs#install"));
    });

    test("reports unavailable (not working) when '--version' exits non-zero", () async {
      final processes = _ProbeProcessService(
        process: _ProbeProcess(pid: 7, stdoutBytes: const <int>[], exitCode: Future<int>.value(1)),
      );

      final result = await const OpenCodePluginDescriptor().checkAvailability(
        config: managedConfig,
        processes: processes,
        environment: const <String, String>{},
      );

      expect(result, isA<PluginUnavailable>());
      final message = (result as PluginUnavailable).message;
      expect(message, contains("did not respond"));
      expect(message, contains("https://opencode.ai/docs#install"));
    });

    test("reports unavailable and force-kills the probe when '--version' hangs", () async {
      final processes = _ProbeProcessService(
        // exitCode never completes -> the probe must time out.
        process: _ProbeProcess(pid: 99, stdoutBytes: const <int>[], exitCode: Completer<int>().future),
      );
      const descriptor = OpenCodePluginDescriptor(versionProbeTimeout: Duration(milliseconds: 20));

      final result = await descriptor.checkAvailability(
        config: managedConfig,
        processes: processes,
        environment: const <String, String>{},
      );

      expect(result, isA<PluginUnavailable>());
      expect((result as PluginUnavailable).message, contains("did not respond"));
      // The hung probe is reaped so it cannot linger.
      expect(processes.forceSignals, equals(<int>[99]));
    });

    test("uses the configured --opencode-bin path in the spawn and the message", () async {
      final processes = _ProbeProcessService(
        spawnError: const ProcessException("/custom/opencode", ["--version"], "No such file or directory", 2),
      );

      final result = await const OpenCodePluginDescriptor().checkAvailability(
        config: const PluginConfig(
          values: {"no-auto-start": false, "port": null, "password": "", "opencode-bin": "/custom/opencode"},
        ),
        processes: processes,
        environment: const <String, String>{},
      );

      expect(result, isA<PluginUnavailable>());
      expect((result as PluginUnavailable).message, contains("/custom/opencode --version"));
      expect(processes.spawnedExecutables, equals(<String>["/custom/opencode"]));
    });
  });
}

/// A [HostProcessService] that either throws on [spawn] (to simulate ENOENT) or
/// returns a single canned [_ProbeProcess]. Records the spawn arguments and any
/// force-kill it is asked to deliver.
class _ProbeProcessService implements HostProcessService {
  _ProbeProcessService({this.spawnError, this.process});

  final Object? spawnError;
  final _ProbeProcess? process;
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
    return process!;
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => null;

  @override
  Future<List<ProcessIdentity>> list({required int? excludePid}) async => const <ProcessIdentity>[];

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
