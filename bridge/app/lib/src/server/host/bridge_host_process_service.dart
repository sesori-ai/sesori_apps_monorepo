import "dart:io" as io;

import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show HostProcessService, Log, ProcessIdentity, ProcessUser, ServerClock, SignalResult, SpawnedProcess;

import "../repositories/process_repository.dart";

/// Spawn seam for [BridgeHostProcessService]; production passes
/// `io.Process.start`. Unlike `OpenCodeProcessStarter` it carries
/// [workingDirectory], which the host contract requires.
typedef HostProcessStarter =
    Future<io.Process> Function(
      String executable,
      List<String> arguments, {
      Map<String, String>? environment,
      String? workingDirectory,
      bool runInShell,
    });

class BridgeHostProcessService implements HostProcessService {
  BridgeHostProcessService({
    required HostProcessStarter processStarter,
    required ProcessRepository processRepository,
    required ServerClock clock,
    required ProcessUser? currentUser,
    required bool isWindows,
    required String platform,
  }) : _processStarter = processStarter,
       _processRepository = processRepository,
       _clock = clock,
       _currentUser = currentUser,
       _isWindows = isWindows,
       _platform = platform;

  final HostProcessStarter _processStarter;
  final ProcessRepository _processRepository;
  final ServerClock _clock;
  final ProcessUser? _currentUser;
  final bool _isWindows;
  final String _platform;

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) async {
    final process = await _processStarter(
      executable,
      arguments,
      environment: environment,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
    );

    final spawnIdentity = ProcessIdentity(
      pid: process.pid,
      startMarker: null,
      executablePath: executable,
      commandLine: [executable, ...arguments].join(" "),
      ownerUser: _currentUser,
      platform: _platform,
      capturedAt: _clock.now(),
    );

    return _HostSpawnedProcess(
      process: process,
      identity: await _resolveSpawnedIdentity(spawnIdentity: spawnIdentity),
    );
  }

  @override
  Future<ProcessIdentity?> inspect({required int pid}) {
    return _processRepository.inspectProcess(pid: pid);
  }

  @override
  Future<List<ProcessIdentity>> list({required int? excludePid}) {
    return _processRepository.listProcessIdentities(excludePid: excludePid);
  }

  @override
  Future<SignalResult> signalGraceful({required int pid}) {
    return _processRepository.sendGracefulSignal(pid: pid);
  }

  @override
  Future<SignalResult> signalForce({required int pid}) {
    return _processRepository.sendForceSignal(pid: pid);
  }

  Future<ProcessIdentity> _resolveSpawnedIdentity({required ProcessIdentity spawnIdentity}) async {
    final ProcessIdentity? inspectedIdentity;
    try {
      inspectedIdentity = await _processRepository.inspectProcess(pid: spawnIdentity.pid);
    } on Exception catch (error) {
      // The child is already running and only the returned handle lets the
      // caller stop it, so a failed process-table read must not fail the
      // spawn — fall back to the partial spawn-time identity.
      Log.w("Post-spawn identity inspection failed for pid ${spawnIdentity.pid}\n$error");
      return spawnIdentity;
    }

    if (inspectedIdentity != null &&
        _matchesSpawnedIdentity(spawnIdentity: spawnIdentity, inspectedIdentity: inspectedIdentity)) {
      return inspectedIdentity;
    }
    return spawnIdentity;
  }

  bool _matchesSpawnedIdentity({
    required ProcessIdentity spawnIdentity,
    required ProcessIdentity inspectedIdentity,
  }) {
    if (inspectedIdentity.pid != spawnIdentity.pid) {
      return false;
    }

    if (_isWindows && _isWindowsImageNameOnlyCommandLine(inspectedIdentity.commandLine)) {
      return _samePath(inspectedIdentity.executablePath, spawnIdentity.executablePath ?? "");
    }

    return inspectedIdentity.commandLine == spawnIdentity.commandLine;
  }

  bool _samePath(String? actual, String expected) {
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

class _HostSpawnedProcess implements SpawnedProcess {
  _HostSpawnedProcess({
    required io.Process process,
    required this.identity,
  }) : _process = process;

  final io.Process _process;

  @override
  final ProcessIdentity identity;

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
