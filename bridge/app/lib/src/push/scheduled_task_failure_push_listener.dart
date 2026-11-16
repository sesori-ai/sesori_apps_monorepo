import "dart:async";

import "package:sesori_shared/sesori_shared.dart";

import "push_dispatcher.dart";
import "push_notification_content_builder.dart";

/// A scheduled task run that could not start, as the push subsystem sees it.
typedef ScheduledTaskFailurePush = ({String taskId, String taskName, TaskRunFailureReason reason});

/// Pushes each scheduled task run that could not start, with the reason.
class ScheduledTaskFailurePushListener({
  required final Stream<ScheduledTaskFailurePush> _source,
  required final PushNotificationContentBuilder _contentBuilder,
  required final PushDispatcher _dispatcher,
}) {
  StreamSubscription<ScheduledTaskFailurePush>? _subscription;

  void start() {
    _subscription ??= _source.listen((failure) {
      final (:title, :body) = _contentBuilder.scheduledTaskFailure(taskName: failure.taskName, reason: failure.reason);
      _dispatcher.dispatchScheduledTaskFailure(taskId: failure.taskId, title: title, body: body);
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
