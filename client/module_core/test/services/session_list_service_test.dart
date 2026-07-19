import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/services/models/session_activity_info.dart";
import "package:sesori_dart_core/src/services/session_activity_calculator.dart";
import "package:sesori_dart_core/src/services/session_list_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockProjectRepository extends Mock implements ProjectRepository {}

void main() {
  test("running sessions form an alphabetical prefix while the tail stays timestamp ordered", () {
    final service = SessionListService(
      repository: _MockProjectRepository(),
      activityCalculator: const SessionActivityCalculator(),
    );

    final result = service.visibleSessions(
      sessions: [
        _session(id: "running-z", title: "Zulu", updatedAt: 400),
        _session(id: "waiting-a", title: "Alpha", updatedAt: 300),
        _session(id: "inactive-b", title: "Beta", updatedAt: 200),
        _session(id: "running-a", title: "Alpha", updatedAt: 100),
      ],
      showArchived: true,
      activityBySessionId: const {
        "running-z": SessionActivityInfo(isRetrying: true),
        "waiting-a": SessionActivityInfo(awaitingInput: true),
        "running-a": SessionActivityInfo(mainAgentRunning: true),
      },
    );

    expect(
      result.map((session) => session.id),
      ["running-a", "running-z", "waiting-a", "inactive-b"],
    );
  });
}

Session _session({required String id, required String title, required int updatedAt}) {
  return Session(
    id: id,
    projectID: "project",
    directory: "/project",
    parentID: null,
    title: title,
    time: SessionTime(created: 1, updated: updatedAt, archived: null),
    pullRequest: null,
    promptDefaults: null,
    branchName: null,
  );
}
