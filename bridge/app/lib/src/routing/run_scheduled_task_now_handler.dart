import "package:sesori_shared/sesori_shared.dart";

import "../services/scheduled_task_run_service.dart";
import "request_handler.dart";

/// Handles `POST /scheduled-task/run-now`: fires a task now without moving its
/// next run.
class RunScheduledTaskNowHandler({required final ScheduledTaskRunService _scheduledTaskRunService})
    extends BodyRequestHandler<ScheduledTaskIdRequest, ScheduledTaskRunResponse> {
  this
    : super(
        method: HttpMethod.post,
        path: "/scheduled-task/run-now",
        fromJson: ScheduledTaskIdRequest.fromJson,
      );

  @override
  Future<ScheduledTaskRunResponse> handle({
    required RelayRequest request,
    required ScheduledTaskIdRequest body,
  }) async {
    requireNonEmpty(request: request, value: body.taskId, label: "task id");
    return ScheduledTaskRunResponse(run: await _scheduledTaskRunService.runNow(taskId: body.taskId));
  }
}
