enum ServerHealthSignalType { serverUnreachable, serverReachable }

class ServerHealthSignal {
  final ServerHealthSignalType type;
  final String? message;

  const ServerHealthSignal({required this.type, this.message});
}
