import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  late _ProjectListCubit projects;
  late _RecentSessionsCubit recent;
  late DesktopSidebarRefreshOrchestrator orchestrator;

  setUp(() {
    projects = _ProjectListCubit();
    recent = _RecentSessionsCubit();
    when(() => projects.state).thenReturn(_loadedProjects(ids: const ["old"]));
    when(() => projects.refreshProjects()).thenAnswer((_) async => true);
    when(() => recent.refreshProjects(projectIds: any(named: "projectIds"))).thenAnswer((_) async => true);
    orchestrator = DesktopSidebarRefreshOrchestrator(projectListCubit: projects, recentSessionsCubit: recent);
  });

  test("refreshes resulting session inventories after the project snapshot", () async {
    final projectReply = Completer<bool>();
    when(() => projects.refreshProjects()).thenAnswer((_) => projectReply.future);
    final pending = orchestrator.refresh();
    verifyNever(() => recent.refreshProjects(projectIds: any(named: "projectIds")));
    when(() => projects.state).thenReturn(_loadedProjects(ids: const ["new", "other"]));
    projectReply.complete(true);

    final result = await pending;

    final captured = verify(() => recent.refreshProjects(projectIds: captureAny(named: "projectIds"))).captured.single;
    expect(captured, orderedEquals(["new", "other"]));
    expect(result, DesktopSidebarRefreshResult.succeeded);
  });

  test("refreshes retained sessions but reports project failure", () async {
    when(() => projects.refreshProjects()).thenAnswer((_) async => false);

    final result = await orchestrator.refresh();

    verify(() => recent.refreshProjects(projectIds: any(named: "projectIds"))).called(1);
    expect(result, DesktopSidebarRefreshResult.failed);
  });

  test("reports session inventory failure", () async {
    when(() => recent.refreshProjects(projectIds: any(named: "projectIds"))).thenAnswer((_) async => false);

    expect(await orchestrator.refresh(), DesktopSidebarRefreshResult.failed);
  });

  test("logs and reports an unexpected workflow failure", () async {
    when(() => projects.refreshProjects()).thenThrow(StateError("unexpected"));

    expect(await orchestrator.refresh(), DesktopSidebarRefreshResult.failed);
    verifyNever(() => recent.refreshProjects(projectIds: any(named: "projectIds")));
  });
}

ProjectListLoaded _loadedProjects({required List<String> ids}) => ProjectListState.loaded(
  projects: [for (final id in ids) ProjectSummary(id: id, name: id, path: "/$id", time: null)],
  activityById: const {},
) as ProjectListLoaded;

class _ProjectListCubit() extends Mock implements ProjectListCubit;
class _RecentSessionsCubit() extends Mock implements RecentSessionsCubit;
