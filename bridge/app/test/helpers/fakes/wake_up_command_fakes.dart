import "package:sesori_bridge/src/services/permission_auto_approval_service.dart";
import "package:sesori_bridge/src/services/scheduled_command_service.dart";

/// Answers [isYolo] from [yoloSessionIds].
class FakeAutoApproval() implements PermissionAutoApprovalService {
  final Set<String> yoloSessionIds = {};

  @override
  Future<bool> isYolo({required String sessionId}) async => yoloSessionIds.contains(sessionId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records the commands it is asked to run and reports [result] for each,
/// running nothing. [beforeResult] runs while the "command" runs.
class RecordingScheduledCommands() implements ScheduledCommandService {
  final List<({String outputKey, String command, String workingDirectory})> runs = [];
  String result = "command exited 0";
  Future<void> Function()? beforeResult;

  @override
  Future<String> run({required String outputKey, required String command, required String workingDirectory}) async {
    runs.add((outputKey: outputKey, command: command, workingDirectory: workingDirectory));
    await beforeResult?.call();
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
