import "package:sesori_shared/sesori_shared.dart";

import "../services/scheduled_task_service.dart";
import "request_handler.dart";

/// Handles `GET /scheduled-tasks`: the computer's tasks, done one-off tasks
/// excluded.
class GetScheduledTasksHandler({required final ScheduledTaskService _scheduledTaskService})
    extends GetRequestHandler<ScheduledTaskListResponse> {
  this : super(path: "/scheduled-tasks");

  @override
  Future<ScheduledTaskListResponse> handle({required RelayRequest request}) => _scheduledTaskService.list();
}
