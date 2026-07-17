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
  StreamSubscription<AcpNotificationRecord>? _subscription;

  void attach() {
    if (_subscription != null) return;
    // Ownership transfers to this listener and is released by dispose().
    // ignore: cancel_subscriptions
    final subscription = notificationRepository.notifications.listen(
      eventDispatcher.consume,
    );
    _subscription = subscription;
  }

  Future<void> dispose() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }
}
