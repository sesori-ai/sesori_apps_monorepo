import "package:sesori_shared/sesori_shared.dart";

import "../services/scheduled_task_service.dart";
import "request_handler.dart";

/// Handles `POST /scheduled-task/runs`: a task's run history, newest first.
class GetScheduledTaskRunsHandler({required final ScheduledTaskService _scheduledTaskService})
    extends BodyRequestHandler<ScheduledTaskIdRequest, ScheduledTaskRunListResponse> {
  this
    : super(
        method: HttpMethod.post,
        path: "/scheduled-task/runs",
        fromJson: ScheduledTaskIdRequest.fromJson,
      );

  @override
  Future<ScheduledTaskRunListResponse> handle({required RelayRequest request, required ScheduledTaskIdRequest body}) {
    requireNonEmpty(request: request, value: body.taskId, label: "task id");
    return _scheduledTaskService.listRuns(taskId: body.taskId);
  }
}
