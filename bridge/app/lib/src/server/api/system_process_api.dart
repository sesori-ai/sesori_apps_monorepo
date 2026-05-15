import "dart:convert";
import "dart:io";

import "../../bridge/foundation/process_runner.dart";
import "../foundation/server_clock.dart";
import "../foundation/shutdown_result.dart";

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

  Future<List<SystemProcessFact>> listProcesses() async {
    return _isWindows ? _listWindowsProcesses() : _listPosixProcesses();
  }

  Future<SystemProcessFact?> inspectProcess({required int pid}) async {
    final processes = await listProcesses();
    for (final process in processes) {
      if (process.pid == pid) {
        return process;
      }
    }
    return null;
  }

  Future<ShutdownResult> sendGracefulSignal({required int pid}) async {
    final signal = _isWindows ? ProcessSignal.sigkill : ProcessSignal.sigterm;
    return _sendSignal(
      pid: pid,
      requestedSignal: ShutdownSignal.graceful,
      deliveredSignal: signal.signalName,
      signal: signal,
    );
  }

  Future<ShutdownResult> sendForceSignal({required int pid}) async {
    return _sendSignal(
      pid: pid,
      requestedSignal: ShutdownSignal.force,
      deliveredSignal: ProcessSignal.sigkill.signalName,
      signal: ProcessSignal.sigkill,
    );
  }

  Future<ShutdownResult> _sendSignal({
    required int pid,
    required ShutdownSignal requestedSignal,
    required String deliveredSignal,
    required ProcessSignal signal,
  }) async {
    final wasRequested = pid > 0 && Process.killPid(pid, signal);
    return ShutdownResult(
      pid: pid,
      requestedSignal: requestedSignal,
      deliveredSignal: deliveredSignal,
      wasRequested: wasRequested,
      attemptedAt: _clock.now(),
    );
  }

  Future<List<SystemProcessFact>> _listPosixProcesses() async {
    final result = await _processRunner.run("ps", <String>["-axo", "pid=,user=,lstart=,command="]);
    if (result.exitCode != 0) {
      throw ProcessException("ps", <String>["-axo", "pid=,user=,lstart=,command="], result.stderr.toString(), result.exitCode);
    }

    final capturedAt = _clock.now();
    final processes = <SystemProcessFact>[];
    for (final line in const LineSplitter().convert(result.stdout.toString())) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final match = RegExp(r"^(\d+)\s+(\S+)\s+(.{24})\s+(.*)$").firstMatch(trimmed);
      if (match == null) {
        continue;
      }

      final commandLine = match.group(4) ?? "";
      processes.add(
        SystemProcessFact(
          pid: int.parse(match.group(1)!),
          startMarker: (match.group(3) ?? "").trim(),
          executablePath: _executableFromCommandLine(commandLine: commandLine),
          commandLine: commandLine,
          ownerUser: match.group(2),
          platform: _platform,
          capturedAt: capturedAt,
        ),
      );
    }
    return processes;
  }

  Future<List<SystemProcessFact>> _listWindowsProcesses() async {
    final result = await _processRunner.run("tasklist", <String>["/V", "/FO", "CSV", "/NH"]);
    if (result.exitCode != 0) {
      throw ProcessException("tasklist", <String>["/V", "/FO", "CSV", "/NH"], result.stderr.toString(), result.exitCode);
    }

    final capturedAt = _clock.now();
    final processes = <SystemProcessFact>[];
    for (final line in const LineSplitter().convert(result.stdout.toString())) {
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
        SystemProcessFact(
          pid: pid,
          startMarker: null,
          executablePath: executablePath,
          commandLine: executablePath,
          ownerUser: row[6].isEmpty ? null : row[6],
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

class SystemProcessFact {
  const SystemProcessFact({
    required this.pid,
    required this.startMarker,
    required this.executablePath,
    required this.commandLine,
    required this.ownerUser,
    required this.platform,
    required this.capturedAt,
  });

  final int pid;
  final String? startMarker;
  final String? executablePath;
  final String commandLine;
  final String? ownerUser;
  final String platform;
  final DateTime capturedAt;
}

extension on ProcessSignal {
  String get signalName {
    if (this == ProcessSignal.sigterm) {
      return "sigterm";
    }
    if (this == ProcessSignal.sigkill) {
      return "sigkill";
    }
    return toString();
  }
}
