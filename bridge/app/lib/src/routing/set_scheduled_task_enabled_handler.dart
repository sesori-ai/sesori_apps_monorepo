import "package:sesori_shared/sesori_shared.dart";

import "../services/scheduled_task_service.dart";
import "request_handler.dart";

/// Handles `PATCH /scheduled-task/enabled`: pauses or resumes a task.
class SetScheduledTaskEnabledHandler({required final ScheduledTaskService _scheduledTaskService})
    extends BodyRequestHandler<SetScheduledTaskEnabledRequest, ScheduledTaskResponse> {
  this
    : super(
        method: HttpMethod.patch,
        path: "/scheduled-task/enabled",
        fromJson: SetScheduledTaskEnabledRequest.fromJson,
      );

  @override
  Future<ScheduledTaskResponse> handle({
    required RelayRequest request,
    required SetScheduledTaskEnabledRequest body,
  }) async {
    requireNonEmpty(request: request, value: body.taskId, label: "task id");
    return ScheduledTaskResponse(
      task: await _scheduledTaskService.setEnabled(taskId: body.taskId, enabled: body.enabled),
    );
  }
}
