import "dart:async";

import "../services/scheduled_task_run_failure.dart";
import "push_dispatcher.dart";
import "push_notification_content_builder.dart";

/// Pushes each scheduled task run that could not start, with the reason.
class ScheduledTaskFailurePushListener({
  required final Stream<ScheduledTaskRunFailure> _source,
  required final PushNotificationContentBuilder _contentBuilder,
  required final PushDispatcher _dispatcher,
}) {
  StreamSubscription<ScheduledTaskRunFailure>? _subscription;

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
