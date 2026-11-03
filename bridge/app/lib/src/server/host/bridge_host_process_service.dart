import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        HostProcessService,
        Log,
        ProcessIdentity,
        ProcessLifetime,
        ProcessUser,
        ServerClock,
        SignalResult,
        SpawnedProcess;

import "../repositories/process_repository.dart";

/// Spawn seam for [BridgeHostProcessService]; production passes
/// `io.Process.start`. Unlike `OpenCodeProcessStarter` it carries
/// [workingDirectory], which the host contract requires.
typedef HostProcessStarter = Future<io.Process> Function(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
  String? workingDirectory,
  bool runInShell,
  required bool includeParentEnvironment,
});

class BridgeHostProcessService({
  required final HostProcessStarter _processStarter,
  required final ProcessRepository _processRepository,
  required final ServerClock _clock,
  required final ProcessUser? _currentUser,
  required final bool _isWindows,
}) implements HostProcessService {
  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
    required bool includeParentEnvironment,
    required ProcessLifetime lifetime,
  }) async {
    final process = await _processStarter(
      executable,
      arguments,
      environment: environment,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
      includeParentEnvironment: includeParentEnvironment,
    );
    if (_isWindows && lifetime == ProcessLifetime.endsWithBridge) {
      // ponytail: the child already runs when it is bound, so with runInShell
      // cmd.exe can start the real runtime before the bind lands and that
      // runtime escapes the job, which is today's behaviour. If that is ever
      // seen, launch suspended through CreateProcess over FFI, bind, resume.
      _processRepository.bindToBridgeLifetime(pid: process.pid);
    }

    final spawnIdentity = ProcessIdentity(
      pid: process.pid,
      startMarker: null,
      executablePath: executable,
      commandLine: [executable, ...arguments].join(" "),
      ownerUser: _currentUser,
      capturedAt: _clock.now(),
    );

    return _HostSpawnedProcess(
      process: process,
      identity: await _resolveSpawnedIdentity(
        spawnIdentity: spawnIdentity,
        spawnedExecutable: executable,
        arguments: arguments,
      ),
    );
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) {
    return _processRepository.inspectProcess(pid: pid);
  }

  @override
  Future<SignalResult> signalGraceful({required int pid}) {
    return _processRepository.sendGracefulSignal(pid: pid);
  }

  @override
  Future<SignalResult> signalForce({required int pid}) {
    return _processRepository.sendForceSignal(pid: pid);
  }

  Future<ProcessIdentity> _resolveSpawnedIdentity({
    required ProcessIdentity spawnIdentity,
    required String spawnedExecutable,
    required List<String> arguments,
  }) async {
    final ProcessIdentity? inspectedIdentity;
    try {
      inspectedIdentity = await _processRepository.inspectProcess(pid: spawnIdentity.pid);
    } on Object catch (error, stackTrace) {
      // The child is already running and only the returned handle lets the
      // caller stop it, so nothing thrown by the process-table read — Errors
      // included — may fail the spawn. Fall back to the partial spawn-time
      // identity.
      Log.w("Post-spawn identity inspection failed for pid ${spawnIdentity.pid}", error, stackTrace);
      return spawnIdentity;
    }

    if (inspectedIdentity != null &&
        _matchesSpawnedIdentity(
          spawnIdentity: spawnIdentity,
          spawnedExecutable: spawnedExecutable,
          inspectedIdentity: inspectedIdentity,
          arguments: arguments,
        )) {
      return inspectedIdentity;
    }
    return spawnIdentity;
  }

  bool _matchesSpawnedIdentity({
    required ProcessIdentity spawnIdentity,
    required String spawnedExecutable,
    required ProcessIdentity inspectedIdentity,
    required List<String> arguments,
  }) {
    if (inspectedIdentity.pid != spawnIdentity.pid) {
      return false;
    }

    if (_isWindows && _isWindowsImageNameOnlyCommandLine(inspectedIdentity.commandLine)) {
      return _samePath(actual: inspectedIdentity.executablePath, expected: spawnedExecutable);
    }

    final inspectedCommandLine = inspectedIdentity.commandLine;
    final spawnCommandLine = spawnIdentity.commandLine;
    if (inspectedCommandLine == spawnCommandLine) {
      return true;
    }

    // The executable part of the live command line can differ from what we
    // spawned while the arguments stay ours: an interpreter shim (a
    // `#!/usr/bin/env node` script) shows as `node <shim> <args>`, and a
    // launcher that execs its native binary in the same pid shows as
    // `<native> <args>`. This is the pid we just spawned, so ending with our
    // exact arguments is enough to adopt the identity and its start marker.
    // Without the marker the ownership record never re-matches the child, so
    // the bridge could not stop it and its port would leak.
    final spawnArguments = arguments.join(" ");
    return spawnArguments.isNotEmpty && inspectedCommandLine.endsWith(" $spawnArguments");
  }

  bool _samePath({required String? actual, required String expected}) {
    if (actual == null) {
      return false;
    }

    if (_isWindows) {
      final normalizedActual = _normalizeWindowsPath(actual);
      final normalizedExpected = _normalizeWindowsPath(expected);
      if (normalizedActual == normalizedExpected) {
        return true;
      }

      return _windowsPathBasename(normalizedActual) == _windowsPathBasename(normalizedExpected);
    }

    return actual == expected;
  }

  bool _isWindowsImageNameOnlyCommandLine(String commandLine) {
    return commandLine.isNotEmpty && !commandLine.contains(" ") && !commandLine.contains("\t");
  }

  String _normalizeWindowsPath(String path) {
    var normalized = path.replaceAll("/", String.fromCharCode(92));
    if (normalized.toLowerCase().endsWith(".exe")) {
      normalized = normalized.substring(0, normalized.length - 4);
    }
    return normalized.toLowerCase();
  }

  String _windowsPathBasename(String path) {
    final segments = path.split(RegExp(r"[\\/]+"));
    return segments.isEmpty ? path : segments.last;
  }
}

class _HostSpawnedProcess({
  required final io.Process _process,
  @override required final ProcessIdentity identity,
}) implements SpawnedProcess {
  @override
  int get pid => _process.pid;

  @override
  io.IOSink get stdin => _process.stdin;

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  Future<int> get exitCode => _process.exitCode;
}
