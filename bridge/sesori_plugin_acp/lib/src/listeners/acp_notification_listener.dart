import "dart:async";

import "../dispatchers/acp_turn_event_dispatcher.dart";
import "../repositories/acp_notification_repository.dart";
import "../repositories/models/acp_notification_record.dart";

class AcpNotificationListener {
  AcpNotificationListener({
    required this.notificationRepository,
    required this.eventDispatcher,
  });

  final AcpNotificationRepository notificationRepository;
  final AcpTurnEventDispatcher eventDispatcher;
  // The analyzer cannot trace cancellation through this listener's dispose().
  // ignore: cancel_subscriptions
  StreamSubscription<AcpNotificationRecord>? _subscription;

  void attach() {
    if (_subscription != null) return;
    _subscription = notificationRepository.notifications.listen(
      eventDispatcher.consume,
    );
  }

  Future<void> dispose() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
