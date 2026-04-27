sealed class ServerHealthEvent {
  const ServerHealthEvent();
}

class ServerHealthEventRunning extends ServerHealthEvent {
  const ServerHealthEventRunning();
}

class ServerHealthEventUnreachable extends ServerHealthEvent {
  final String? message;
  const ServerHealthEventUnreachable({this.message});
}

class ServerHealthEventRestarting extends ServerHealthEvent {
  final int attempt; // 1..4
  const ServerHealthEventRestarting({required this.attempt});
}

class ServerHealthEventFailed extends ServerHealthEvent {
  final String reason;
  const ServerHealthEventFailed({required this.reason});
}
