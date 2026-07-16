import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/services/session_list_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockProjectRepository extends Mock implements ProjectRepository {}

void main() {
  late SessionListService service;

  setUp(() {
    service = SessionListService(repository: _MockProjectRepository());
  });

  test("ordered summaries define the active prefix and preserve the legacy tail", () {
    final result = service.visibleSessions(
      sessions: [
        _session(id: "inactive-z", title: "Zulu"),
        _session(id: "active-a", title: "Alpha"),
        _session(id: "inactive-a", title: "Alpha"),
        _session(id: "active-z", title: "Zulu"),
      ],
      showArchived: true,
      activeSessionIds: const ["active-z", "active-a"],
      userInteractionOrdered: true,
    );

    expect(result.map((session) => session.id), ["active-z", "active-a", "inactive-a", "inactive-z"]);
  });

  test("older summaries retain the complete legacy session order", () {
    final result = service.visibleSessions(
      sessions: [
        _session(id: "z", title: "Zulu"),
        _session(id: "a", title: "Alpha"),
      ],
      showArchived: true,
      activeSessionIds: const ["z"],
      userInteractionOrdered: false,
    );

    expect(result.map((session) => session.id), ["a", "z"]);
  });

  test("archived sessions remain filtered before active order is applied", () {
    final result = service.visibleSessions(
      sessions: [
        _session(id: "archived", title: "Archived", archivedAt: 1),
        _session(id: "visible", title: "Visible"),
      ],
      showArchived: false,
      activeSessionIds: const ["archived", "visible"],
      userInteractionOrdered: true,
    );

    expect(result.map((session) => session.id), ["visible"]);
  });
}

Session _session({required String id, required String title, int? archivedAt}) {
  return Session(
    id: id,
    projectID: "project",
    directory: "/project",
    parentID: null,
    title: title,
    time: SessionTime(created: 1, updated: 1, archived: archivedAt),
    pullRequest: null,
    promptDefaults: null,
  );
}
