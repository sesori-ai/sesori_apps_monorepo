import "package:sesori_shared/sesori_shared.dart";

import "../services/scheduled_task_service.dart";
import "request_handler.dart";

/// Handles `DELETE /scheduled-task/delete`. The task's sessions stay.
class DeleteScheduledTaskHandler({required final ScheduledTaskService _scheduledTaskService})
    extends BodyRequestHandler<ScheduledTaskIdRequest, SuccessEmptyResponse> {
  this
    : super(
        method: HttpMethod.delete,
        path: "/scheduled-task/delete",
        fromJson: ScheduledTaskIdRequest.fromJson,
      );

  @override
  Future<SuccessEmptyResponse> handle({required RelayRequest request, required ScheduledTaskIdRequest body}) async {
    requireNonEmpty(request: request, value: body.taskId, label: "task id");
    await _scheduledTaskService.delete(taskId: body.taskId);
    return const SuccessEmptyResponse();
  }
}
