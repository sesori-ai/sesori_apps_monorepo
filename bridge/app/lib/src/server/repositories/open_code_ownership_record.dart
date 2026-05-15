enum OpenCodeOwnershipStatus {
  starting,
  ready,
  stopping,
}

class OpenCodeOwnershipRecord {
  final String ownerSessionId;
  final int openCodePid;
  final String? openCodeStartMarker;
  final String openCodeExecutablePath;
  final String openCodeCommand;
  final List<String> openCodeArgs;
  final int port;
  final int bridgePid;
  final String? bridgeStartMarker;
  final DateTime startedAt;
  final OpenCodeOwnershipStatus status;

  const OpenCodeOwnershipRecord({
    required this.ownerSessionId,
    required this.openCodePid,
    required this.openCodeStartMarker,
    required this.openCodeExecutablePath,
    required this.openCodeCommand,
    required this.openCodeArgs,
    required this.port,
    required this.bridgePid,
    required this.bridgeStartMarker,
    required this.startedAt,
    required this.status,
  });
}
