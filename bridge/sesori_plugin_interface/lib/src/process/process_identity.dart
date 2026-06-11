import "process_user.dart";

class ProcessIdentity {
  const ProcessIdentity({
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
  final ProcessUser? ownerUser;
  final String platform;
  final DateTime capturedAt;

  bool hasSameIdentityAs(ProcessIdentity other) {
    if (pid != other.pid) {
      return false;
    }
    if (startMarker != null || other.startMarker != null) {
      // we can use start marker to determine if it's the same process
      // -- this + same pid is enough to determine
      return startMarker == other.startMarker;
    }

    if (commandLine != other.commandLine) {
      return false;
    }

    return executablePath == other.executablePath;
  }
}
