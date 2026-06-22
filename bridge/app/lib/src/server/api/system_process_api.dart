import "dart:convert";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../bridge/foundation/process_runner.dart";

class SystemProcessApi {
  SystemProcessApi({
    required ProcessRunner processRunner,
    required ServerClock clock,
    required bool isWindows,
    required String platform,
  }) : _processRunner = processRunner,
       _clock = clock,
       _isWindows = isWindows,
       _platform = platform;

  final ProcessRunner _processRunner;
  final ServerClock _clock;
  final bool _isWindows;
  final String _platform;

  Future<List<ProcessIdentity>> listProcesses() async {
    return _isWindows ? _listWindowsProcesses() : _listPosixProcesses();
  }

  /// Spawns [executable] detached (inheriting stdio), returning its pid without
  /// waiting. Used to launch a successor bridge during a restart.
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) {
    return _processRunner.startDetached(executable: executable, arguments: arguments, environment: environment);
  }

  Future<ProcessIdentity?> inspectProcess({required int pid}) async {
    // A non-positive PID never identifies a real process. Reject it up front so
    // every platform returns null consistently — otherwise the Windows
    // `tasklist /FI "PID eq <pid>"` path would exit non-zero and throw, while
    // the POSIX list-and-filter path would simply find no match.
    if (pid <= 0) {
      return null;
    }
    if (_isWindows) {
      return _inspectWindowsProcess(pid: pid);
    }
    final processes = await _listPosixProcesses();
    for (final process in processes) {
      if (process.pid == pid) {
        return process;
      }
    }
    return null;
  }

  Future<SignalResult> sendGracefulSignal({required int pid}) => _sendSignal(
    pid: pid,
    requestedSignal: .graceful,
    deliveredSignal: _isWindows ? .sigkill : .sigterm,
  );

  Future<SignalResult> sendForceSignal({required int pid}) => _sendSignal(
    pid: pid,
    requestedSignal: .force,
    deliveredSignal: .sigkill,
  );

  Future<SignalResult> _sendSignal({
    required int pid,
    required ShutdownSignal requestedSignal,
    required ProcessSignal deliveredSignal,
  }) async {
    final wasRequested = pid > 0 && Process.killPid(pid, deliveredSignal);
    return SignalResult(
      pid: pid,
      requestedSignal: requestedSignal,
      deliveredSignal: deliveredSignal,
      wasRequested: wasRequested,
      attemptedAt: _clock.now(),
    );
  }

  Future<List<ProcessIdentity>> _listPosixProcesses() async {
    final (command, args) = ("ps", <String>["-axwwo", "pid=,user=,lstart=,command="]);
    final result = await _processRunner.run(
      command,
      args,
      environment: {"LC_ALL": "C"},
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        command,
        args,
        result.stderr.toString(),
        result.exitCode,
      );
    }

    final capturedAt = _clock.now();
    final processes = <ProcessIdentity>[];
    for (final line in const LineSplitter().convert(result.stdout.toString())) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final match = RegExp(r"^(\d+)\s+(\S+)\s+(.{24})\s+(.*)$").firstMatch(trimmed);
      if (match == null) {
        continue;
      }
      final pidString = match.group(1);
      if (pidString == null) {
        throw Exception("Failed to extract PID for posix process: ${match.toString()}");
      }

      final owner = ProcessUser.fromRawUser(match.group(2));
      final startMaker = (match.group(3) ?? "").trim();
      final commandLine = (match.group(4) ?? "").trim();
      processes.add(
        ProcessIdentity(
          pid: int.parse(pidString),
          startMarker: startMaker,
          executablePath: _executableFromCommandLine(commandLine: commandLine),
          commandLine: commandLine,
          ownerUser: owner,
          platform: _platform,
          capturedAt: capturedAt,
        ),
      );
    }
    return processes;
  }

  Future<List<ProcessIdentity>> _listWindowsProcesses() async {
    final (command, args) = ("tasklist", <String>["/V", "/FO", "CSV", "/NH"]);
    final result = await _processRunner.run(command, args);
    if (result.exitCode != 0) {
      throw ProcessException(
        command,
        args,
        result.stderr.toString(),
        result.exitCode,
      );
    }

    return _parseWindowsProcesses(stdout: result.stdout.toString());
  }

  /// Inspects a single Windows process by querying `tasklist` with its
  /// server-side `/FI "PID eq <pid>"` filter so the OS returns only the
  /// matching row. This avoids enumerating the entire process table (the
  /// `/V` full scan), which is slow enough right after login to exceed the
  /// [ProcessRunner] timeout.
  Future<ProcessIdentity?> _inspectWindowsProcess({required int pid}) async {
    final (command, args) = (
      "tasklist",
      <String>["/V", "/FO", "CSV", "/NH", "/FI", "PID eq $pid"],
    );
    final result = await _processRunner.run(command, args);
    if (result.exitCode != 0) {
      throw ProcessException(
        command,
        args,
        result.stderr.toString(),
        result.exitCode,
      );
    }

    final processes = _parseWindowsProcesses(stdout: result.stdout.toString());
    for (final process in processes) {
      if (process.pid == pid) {
        return process;
      }
    }
    return null;
  }

  List<ProcessIdentity> _parseWindowsProcesses({required String stdout}) {
    final capturedAt = _clock.now();
    final processes = <ProcessIdentity>[];
    for (final line in const LineSplitter().convert(stdout)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final row = _parseCsvLine(line: trimmed);
      if (row.length < 7) {
        continue;
      }

      final pid = int.tryParse(row[1]);
      if (pid == null) {
        continue;
      }

      final executablePath = row[0];
      processes.add(
        ProcessIdentity(
          pid: pid,
          startMarker: null,
          executablePath: executablePath,
          commandLine: executablePath,
          ownerUser: ProcessUser.fromRawUser(row[6].isEmpty ? null : row[6]),
          platform: _platform,
          capturedAt: capturedAt,
        ),
      );
    }
    return processes;
  }

  static String? _executableFromCommandLine({required String commandLine}) {
    final trimmed = commandLine.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.startsWith('"')) {
      final endQuote = trimmed.indexOf('"', 1);
      if (endQuote > 1) {
        return trimmed.substring(1, endQuote);
      }
    }
    final spaceIndex = trimmed.indexOf(" ");
    if (spaceIndex == -1) {
      return trimmed;
    }
    return trimmed.substring(0, spaceIndex);
  }

  static List<String> _parseCsvLine({required String line}) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < line.length; index += 1) {
      final character = line[index];
      if (character == '"') {
        if (inQuotes && index + 1 < line.length && line[index + 1] == '"') {
          buffer.write('"');
          index += 1;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (character == "," && !inQuotes) {
        values.add(buffer.toString());
        buffer.clear();
        continue;
      }

      buffer.write(character);
    }

    values.add(buffer.toString());
    return values;
  }
}
