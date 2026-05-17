import "package:path/path.dart" as path;

import "../api/system_process_api.dart";
import "../foundation/process_identity.dart";
import "../foundation/process_match.dart";
import "../foundation/shutdown_result.dart";

class ProcessRepository {
  ProcessRepository({
    required SystemProcessApi api,
    required String? currentUser,
  }) : _api = api,
       _currentUser = currentUser;

  final SystemProcessApi _api;
  final String? _currentUser;

  Future<ProcessIdentity?> inspectProcess({required int pid}) async {
    final identity = await _api.inspectProcess(pid: pid);
    if (identity == null) {
      return null;
    }
    return identity;
  }

  Future<ProcessMatch?> inspectProcessMatch({required int pid}) async {
    final identity = await inspectProcess(pid: pid);
    if (identity == null) {
      return null;
    }
    return _toMatch(identity: identity);
  }

  Future<List<ProcessIdentity>> listProcessIdentities({required int? excludePid}) async {
    final processes = await _api.listProcesses();
    final identities = <ProcessIdentity>[];
    for (final identity in processes) {
      if (excludePid != null && identity.pid == excludePid) {
        continue;
      }
      identities.add(identity);
    }
    return identities;
  }

  Future<List<ProcessMatch>> listProcesses({required int? excludePid}) async {
    final identities = await listProcessIdentities(excludePid: excludePid);
    return identities.map((ProcessIdentity identity) => _toMatch(identity: identity)).toList();
  }

  Future<ShutdownResult> sendGracefulSignal({required int pid}) {
    return _api.sendGracefulSignal(pid: pid);
  }

  Future<ShutdownResult> sendForceSignal({required int pid}) {
    return _api.sendForceSignal(pid: pid);
  }

  ProcessMatch _toMatch({required ProcessIdentity identity}) {
    return ProcessMatch(
      identity: identity,
      kind: _resolveKind(identity: identity),
      isCurrentUserProcess: identity.ownerUser != null &&
          _normalizeUser(identity.ownerUser) == _normalizeUser(_currentUser),
    );
  }

  ProcessMatchKind _resolveKind({required ProcessIdentity identity}) {
    final executableBasename = identity.executablePath == null
        ? null
        : path.basename(identity.executablePath!).toLowerCase();
    final commandLine = identity.commandLine.toLowerCase();

    if (executableBasename == "sesori-bridge" ||
        executableBasename == "sesori-bridge.exe" ||
        commandLine.contains("bridge/app/bin/bridge.dart")) {
      return ProcessMatchKind.sesoriBridge;
    }

    if (executableBasename == "opencode" ||
        executableBasename == "opencode.exe" ||
        commandLine.contains("opencode serve")) {
      return ProcessMatchKind.openCodeServe;
    }

    return ProcessMatchKind.unknown;
  }

  static String? _normalizeUser(String? user) {
    if (user == null) return null;
    final backslashIndex = user.lastIndexOf(r'\');
    if (backslashIndex >= 0) {
      return user.substring(backslashIndex + 1);
    }
    return user;
  }
}
