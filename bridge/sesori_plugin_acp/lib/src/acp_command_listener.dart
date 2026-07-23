import "dart:async";

import "acp_command_tracker.dart";
import "acp_stdio_client.dart";

/// Owns one ACP command-advertisement subscription.
class AcpCommandListener {
  AcpCommandListener({
    required Stream<AcpNotification> notifications,
    required AcpCommandTracker tracker,
  }) : _subscription = notifications.listen(tracker.consume);

  final StreamSubscription<AcpNotification> _subscription;

  Future<void> dispose() => _subscription.cancel();
}
