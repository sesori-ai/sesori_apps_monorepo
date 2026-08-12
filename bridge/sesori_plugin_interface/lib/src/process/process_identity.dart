import "process_user.dart";

class const ProcessIdentity({
  required final int pid,
  required final String? startMarker,
  required final String? executablePath,
  required final String commandLine,
  required final ProcessUser? ownerUser,
  required final String platform,
  required final DateTime capturedAt,
}) {
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
