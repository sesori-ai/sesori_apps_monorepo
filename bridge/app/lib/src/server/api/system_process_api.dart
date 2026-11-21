import "dart:convert";
import "dart:io";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../../foundation/csv_parser.dart";
import "../../foundation/process_runner.dart";

class SystemProcessApi({
  required final ProcessRunner _processRunner,
  required final ServerClock _clock,
  required final bool _isWindows,
}) {
  Future<ProcessIdentity?> inspectProcess({required int pid}) async {
    // A non-positive PID never identifies a real process. Reject it up front so
    // every platform returns null consistently — otherwise the Windows
    // `tasklist /FI "PID eq <pid>"` path would exit non-zero and throw, while
    // the POSIX list-and-filter path would simply find no match.
    if (pid <= 0) {
      return null;
    }
    if (_isWindows) {
      return await _inspectWindowsProcess(pid: pid);
    }
    return await _inspectPosixProcess(pid: pid);
  }

  Future<SignalResult> sendGracefulSignal({required int pid}) => _isWindows
      ? _sendWindowsSignal(pid: pid, requestedSignal: .graceful, force: false, includeTree: true)
      : _sendSignal(pid: pid, requestedSignal: .graceful, deliveredSignal: .sigterm);

  Future<SignalResult> sendForceSignal({required int pid}) => _isWindows
      ? _sendWindowsSignal(pid: pid, requestedSignal: .force, force: true, includeTree: true)
      : _sendSignal(pid: pid, requestedSignal: .force, deliveredSignal: .sigkill);

  /// Windows only: force-kills [pid] alone (`taskkill /PID <pid> /F`, no `/T`).
  Future<SignalResult> killWindowsProcess({required int pid, required ShutdownSignal requestedSignal}) =>
      _sendWindowsSignal(pid: pid, requestedSignal: requestedSignal, force: true, includeTree: false);

  /// The processes descending from [pid] right now, read from one snapshot of
  /// the process table (`ps` on POSIX, CIM `Win32_Process` on Windows). A
  /// descendant whose arguments include one of [sharedHelperArguments] is left
  /// out together with everything below it.
  Future<List<int>> listDescendants({required int pid, required Set<String> sharedHelperArguments}) async {
    final processes = _isWindows ? await _listWindowsProcesses() : await _listPosixProcesses();
    final childrenByParent = <int, List<int>>{};
    final sharedHelpers = <int>{};
    for (final process in processes) {
      if (process.pid == process.parent) continue;
      (childrenByParent[process.parent] ??= <int>[]).add(process.pid);
      if (process.arguments.any(sharedHelperArguments.contains)) sharedHelpers.add(process.pid);
    }

    final descendants = <int>[];
    final pending = <int>[pid];
    while (pending.isNotEmpty) {
      for (final child in childrenByParent[pending.removeLast()] ?? const <int>[]) {
        if (sharedHelpers.contains(child)) continue;
        descendants.add(child);
        pending.add(child);
      }
    }
    return descendants;
  }

  Future<List<_ProcessTableRow>> _listPosixProcesses() async {
    const command = "ps";
    // Piped `ps` prints whole arguments on macOS, procps and BusyBox; BusyBox
    // rejects `-ww`.
    const args = <String>["-A", "-o", "pid=,ppid=,args="];
    final result = await _processRunner.run(
      executable: command,
      arguments: args,
      environment: {"LC_ALL": "C"},
      workingDirectory: null,
    );
    if (result.exitCode != 0) {
      throw ProcessException(command, args, result.stderr.toString(), result.exitCode);
    }

    final processes = <_ProcessTableRow>[];
    for (final line in const LineSplitter().convert(result.stdout.toString())) {
      final fields = line.trim().split(RegExp(r"\s+"));
      if (fields.length < 2) continue;
      final child = int.tryParse(fields[0]);
      final parent = int.tryParse(fields[1]);
      if (child == null || parent == null) continue;
      processes.add((pid: child, parent: parent, arguments: fields.skip(2).toList()));
    }
    return processes;
  }

  /// Windows keeps a dead parent's id in `ParentProcessId`, and the id can be
  /// reused, so a process only counts as a child when it started after its
  /// parent.
  Future<List<_ProcessTableRow>> _listWindowsProcesses() async {
    const command = "powershell.exe";
    const args = <String>[
      "-NoProfile",
      "-NonInteractive",
      "-Command",
      _windowsProcessTableScript,
    ];
    final result = await _processRunner.run(
      executable: command,
      arguments: args,
      environment: null,
      workingDirectory: null,
    );
    if (result.exitCode != 0) {
      throw ProcessException(command, args, result.stderr.toString(), result.exitCode);
    }

    final rows = <({int pid, int parent, int? created, String commandLine})>[];
    for (final line in const LineSplitter().convert(result.stdout.toString())) {
      final fields = CsvParser.parseLine(line: line.trim());
      if (fields.length < 4) continue;
      final child = int.tryParse(fields[0]);
      final parent = int.tryParse(fields[1]);
      if (child == null || parent == null) continue;
      rows.add((pid: child, parent: parent, created: int.tryParse(fields[2]), commandLine: fields[3]));
    }
    final createdByPid = {for (final row in rows) row.pid: row.created};
    return [
      for (final row in rows)
        if ((row.created, createdByPid[row.parent]) case (final int created, final int parentCreated)
            when created >= parentCreated)
          (pid: row.pid, parent: row.parent, arguments: row.commandLine.trim().split(RegExp(r"\s+"))),
    ];
  }

  Future<SignalResult> _sendWindowsSignal({
    required int pid,
    required ShutdownSignal requestedSignal,
    required bool force,
    required bool includeTree,
  }) async {
    final attemptedAt = _clock.now();
    // SignalResult has POSIX-shaped vocabulary. `sigterm` represents the
    // non-forced taskkill request; `/F` is the hard-kill escalation.
    final deliveredSignal = force ? ProcessSignal.sigkill : ProcessSignal.sigterm;
    if (pid <= 0) {
      return SignalResult(
        pid: pid,
        requestedSignal: requestedSignal,
        deliveredSignal: deliveredSignal,
        wasRequested: false,
        attemptedAt: attemptedAt,
      );
    }
    // Check absence before signalling. After a failed `/T` request, inspecting
    // only the root cannot prove the descendants were terminated: taskkill may
    // have killed the root before failing on one of its children.
    try {
      if (await _inspectWindowsProcess(pid: pid) == null) {
        return SignalResult(
          pid: pid,
          requestedSignal: requestedSignal,
          deliveredSignal: deliveredSignal,
          wasRequested: false,
          attemptedAt: attemptedAt,
        );
      }
    } on Object catch (error, stackTrace) {
      // An unavailable inspection must not suppress the best-effort signal.
      // A non-zero taskkill result below remains a diagnostic failure.
      Log.w("Could not inspect Windows process $pid before signalling; attempting taskkill", error, stackTrace);
    }
    final arguments = <String>["/PID", "$pid", if (includeTree) "/T", if (force) "/F"];
    final result = await _processRunner.run(
      executable: "taskkill",
      arguments: arguments,
      workingDirectory: null,
      environment: null,
    );
    if (result.exitCode != 0) {
      final stdout = result.stdout.toString().trim();
      final stderr = result.stderr.toString().trim();
      final details = [
        if (stdout.isNotEmpty) "stdout: $stdout",
        if (stderr.isNotEmpty) "stderr: $stderr",
        if (stdout.isEmpty && stderr.isEmpty) "taskkill exited ${result.exitCode} for pid $pid",
      ].join("\n");
      throw ProcessException("taskkill", arguments, details, result.exitCode);
    }
    return SignalResult(
      pid: pid,
      requestedSignal: requestedSignal,
      deliveredSignal: deliveredSignal,
      wasRequested: true,
      attemptedAt: attemptedAt,
    );
  }

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

  /// Inspects a single POSIX process by querying `ps -p <pid>` so the OS
  /// returns only the matching row. This mirrors [_inspectWindowsProcess] and
  /// avoids enumerating the whole process table just to look up one pid.
  ///
  /// `ps -p` exits non-zero both when the pid is simply gone AND when the
  /// invocation genuinely fails (e.g. a usage/format error or `ps` itself
  /// failing), and on BSD `ps` the exit code is `1` in every case — so the exit
  /// code alone cannot distinguish them. We disambiguate via stderr: a vanished
  /// pid produces empty stdout and empty stderr, so we treat non-zero + empty
  /// stderr as "no such process" and return `null`. A non-zero exit with stderr
  /// content is a real failure and is rethrown as a [ProcessException] — never
  /// swallowed — because callers such as `BridgeRuntimeRunner` rely on POSIX
  /// self-inspection errors staying fatal (a marker-less fallback would corrupt
  /// the startup lock).
  ///
  /// The targeted form drops the `a`/`x` list selectors but keeps `-ww` so long
  /// command lines are never truncated, and reuses the same `-o` column spec so
  /// [_parsePosixProcesses]'s 24-char `lstart` regex matches.
  Future<ProcessIdentity?> _inspectPosixProcess({required int pid}) async {
    final (command, args) = ("ps", <String>["-p", "$pid", "-wwo", "pid=,user=,lstart=,command="]);
    final result = await _processRunner.run(
      executable: command,
      arguments: args,
      environment: {"LC_ALL": "C"},
      workingDirectory: null,
    );
    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      if (stderr.isEmpty) {
        return null;
      }
      throw ProcessException(command, args, stderr, result.exitCode);
    }

    final processes = _parsePosixProcesses(stdout: result.stdout.toString());
    for (final process in processes) {
      if (process.pid == pid) {
        return process;
      }
    }
    return null;
  }

  List<ProcessIdentity> _parsePosixProcesses({required String stdout}) {
    final capturedAt = _clock.now();
    final processes = <ProcessIdentity>[];
    for (final line in const LineSplitter().convert(stdout)) {
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
          capturedAt: capturedAt,
        ),
      );
    }
    return processes;
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
    final result = await _processRunner.run(
      executable: command,
      arguments: args,
      workingDirectory: null,
      environment: null,
    );
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

      final row = CsvParser.parseLine(line: trimmed);
      if (row.length < 2) {
        continue;
      }

      final pid = int.tryParse(row[1]);
      if (pid == null) {
        continue;
      }

      final executablePath = row[0];
      final ownerUser = row.length > 6 ? ProcessUser.fromRawUser(row[6].isEmpty ? null : row[6]) : null;
      processes.add(
        ProcessIdentity(
          pid: pid,
          startMarker: null,
          executablePath: executablePath,
          commandLine: executablePath,
          ownerUser: ownerUser,
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
}

const _windowsProcessTableScript =
    "Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, "
    r"@{n='CreationTime';e={if ($_.CreationDate) { $_.CreationDate.ToFileTimeUtc() }}}, CommandLine "
    "| ConvertTo-Csv -NoTypeInformation";

/// One process from a process-table snapshot.
typedef _ProcessTableRow = ({int pid, int parent, List<String> arguments});
