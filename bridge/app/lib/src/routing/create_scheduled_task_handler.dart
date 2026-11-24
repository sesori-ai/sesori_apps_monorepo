import "package:sesori_shared/sesori_shared.dart";

import "../services/scheduled_task_service.dart";
import "request_handler.dart";

/// Handles `POST /scheduled-task/create`. Refusals carry a
/// [ScheduledTaskErrorResponse].
class CreateScheduledTaskHandler({required final ScheduledTaskService _scheduledTaskService})
    extends BodyRequestHandler<CreateScheduledTaskRequest, ScheduledTaskResponse> {
  this
    : super(
        method: HttpMethod.post,
        path: "/scheduled-task/create",
        fromJson: CreateScheduledTaskRequest.fromJson,
      );

  @override
  Future<ScheduledTaskResponse> handle({
    required RelayRequest request,
    required CreateScheduledTaskRequest body,
  }) async {
    return ScheduledTaskResponse(
      task: await _scheduledTaskService.create(
        definition: body.definition,
        // The app cannot set a command; only an allowed agent request does.
        command: null,
      ),
    );
  }
}
