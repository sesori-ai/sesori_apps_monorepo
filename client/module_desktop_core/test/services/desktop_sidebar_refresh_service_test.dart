import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  late _ProjectInventoryRefreshOperation projects;
  late _SessionInventoryRefreshOperation sessions;
  late DesktopSidebarRefreshService service;

  setUp(() {
    projects = _ProjectInventoryRefreshOperation();
    sessions = _SessionInventoryRefreshOperation();
    when(projects.refreshProjectInventory).thenAnswer(
      (_) async => const ProjectInventoryRefreshResult(succeeded: true, projectIds: ["old"]),
    );
    when(() => sessions.refreshProjects(projectIds: any(named: "projectIds"))).thenAnswer((_) async => true);
    service = DesktopSidebarRefreshService(projectInventory: projects, sessionInventory: sessions);
  });

  test("refreshes resulting session inventories after the project snapshot", () async {
    final projectReply = Completer<ProjectInventoryRefreshResult>();
    when(projects.refreshProjectInventory).thenAnswer((_) => projectReply.future);
    final pending = service.refresh();
    verifyNever(() => sessions.refreshProjects(projectIds: any(named: "projectIds")));
    projectReply.complete(
      const ProjectInventoryRefreshResult(succeeded: true, projectIds: ["new", "other"]),
    );

    final result = await pending;

    final captured = verify(
      () => sessions.refreshProjects(projectIds: captureAny(named: "projectIds")),
    ).captured.single;
    expect(captured, orderedEquals(["new", "other"]));
    expect(result, DesktopSidebarRefreshResult.succeeded);
  });

  test("refreshes retained sessions but reports project failure", () async {
    when(projects.refreshProjectInventory).thenAnswer(
      (_) async => const ProjectInventoryRefreshResult(succeeded: false, projectIds: ["retained"]),
    );

    final result = await service.refresh();

    verify(() => sessions.refreshProjects(projectIds: ["retained"])).called(1);
    expect(result, DesktopSidebarRefreshResult.failed);
  });

  test("reports session inventory failure", () async {
    when(() => sessions.refreshProjects(projectIds: any(named: "projectIds"))).thenAnswer((_) async => false);

    expect(await service.refresh(), DesktopSidebarRefreshResult.failed);
  });

  test("logs and reports an unexpected workflow failure", () async {
    when(projects.refreshProjectInventory).thenThrow(StateError("unexpected"));

    expect(await service.refresh(), DesktopSidebarRefreshResult.failed);
    verifyNever(() => sessions.refreshProjects(projectIds: any(named: "projectIds")));
  });
}

class _ProjectInventoryRefreshOperation() extends Mock implements ProjectInventoryRefreshOperation;
class _SessionInventoryRefreshOperation() extends Mock implements SessionInventoryRefreshOperation;
