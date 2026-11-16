import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockScheduledTaskApi() extends Mock implements ScheduledTaskApi;

void main() {
  late _MockScheduledTaskApi api;
  late ScheduledTaskRepository repository;

  setUp(() {
    api = _MockScheduledTaskApi();
    repository = ScheduledTaskRepository(api: api);
  });

  Future<ScheduledTaskResult<ScheduledTaskRun>> runNowAnswering({required ApiError error}) {
    when(() => api.runNow(taskId: "task")).thenAnswer((_) async => ApiResponse.error(error));
    return repository.runNow(taskId: "task");
  }

  test("a typed refusal is a refusal, even on a 404", () async {
    for (final (status, code) in [
      (409, ScheduledTaskErrorCode.previousRunActive),
      (404, ScheduledTaskErrorCode.taskNotFound),
    ]) {
      final result = await runNowAnswering(
        error: NonSuccessCodeError(
          errorCode: status,
          rawErrorString: jsonEncode(ScheduledTaskErrorResponse(code: code).toJson()),
        ),
      );
      expect(result, isA<ScheduledTaskRefused<ScheduledTaskRun>>().having((result) => result.code, "code", code));
    }
  });

  test("a bare 404 means the bridge predates scheduled tasks", () async {
    final result = await runNowAnswering(
      error: NonSuccessCodeError(errorCode: 404, rawErrorString: "Not found"),
    );
    expect(result, isA<ScheduledTaskBridgeOutdated<ScheduledTaskRun>>());
  });

  test("any other error is a failure", () async {
    final result = await runNowAnswering(error: NonSuccessCodeError(errorCode: 503, rawErrorString: null));
    expect(result, isA<ScheduledTaskFailure<ScheduledTaskRun>>());
  });
}
