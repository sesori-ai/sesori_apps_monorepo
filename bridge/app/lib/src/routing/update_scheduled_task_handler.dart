import "package:sesori_shared/sesori_shared.dart";

import "../services/scheduled_task_service.dart";
import "request_handler.dart";

/// Handles `POST /scheduled-task/update`. Refusals carry a
/// [ScheduledTaskErrorResponse].
class UpdateScheduledTaskHandler({required final ScheduledTaskService _scheduledTaskService})
    extends BodyRequestHandler<UpdateScheduledTaskRequest, ScheduledTaskResponse> {
  this
    : super(
        method: HttpMethod.post,
        path: "/scheduled-task/update",
        fromJson: UpdateScheduledTaskRequest.fromJson,
      );

  @override
  Future<ScheduledTaskResponse> handle({
    required RelayRequest request,
    required UpdateScheduledTaskRequest body,
  }) async {
    requireNonEmpty(request: request, value: body.taskId, label: "task id");
    return ScheduledTaskResponse(
      task: await _scheduledTaskService.update(taskId: body.taskId, definition: body.definition),
    );
  }
}
