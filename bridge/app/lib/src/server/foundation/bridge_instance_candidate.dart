class BridgeInstanceCandidate {
  const BridgeInstanceCandidate({
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
