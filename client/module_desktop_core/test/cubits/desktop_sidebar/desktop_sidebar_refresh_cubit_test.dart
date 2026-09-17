import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  late _ProjectListCubit projects;
  late _RecentSessionsCubit recent;
  late DesktopSidebarRefreshCubit cubit;

  setUp(() {
    projects = _ProjectListCubit();
    recent = _RecentSessionsCubit();
    when(() => projects.state).thenReturn(_loadedProjects(ids: const ["old"]));
    when(() => projects.refreshProjects()).thenAnswer((_) async => true);
    when(() => recent.refreshProjects(projectIds: any(named: "projectIds"))).thenAnswer((_) async => true);
    cubit = DesktopSidebarRefreshCubit(projectListCubit: projects, recentSessionsCubit: recent);
  });

  tearDown(() => cubit.close());

  test("refreshes the resulting project inventories after the project snapshot", () async {
    final projectReply = Completer<bool>();
    when(() => projects.refreshProjects()).thenAnswer((_) => projectReply.future);
    final pending = cubit.refresh();

    expect(cubit.state, isA<DesktopSidebarRefreshInProgress>());
    verifyNever(() => recent.refreshProjects(projectIds: any(named: "projectIds")));
    when(() => projects.state).thenReturn(_loadedProjects(ids: const ["new", "other"]));
    projectReply.complete(true);
    await pending;

    final captured = verify(() => recent.refreshProjects(projectIds: captureAny(named: "projectIds"))).captured.single;
    expect(captured, orderedEquals(["new", "other"]));
    expect(cubit.state, isA<DesktopSidebarRefreshSucceeded>());
  });

  test("coalesces duplicate intent while refreshing", () async {
    final projectReply = Completer<bool>();
    when(() => projects.refreshProjects()).thenAnswer((_) => projectReply.future);
    final first = cubit.refresh();
    final second = cubit.refresh();
    projectReply.complete(true);
    await Future.wait([first, second]);

    verify(() => projects.refreshProjects()).called(1);
    verify(() => recent.refreshProjects(projectIds: any(named: "projectIds"))).called(1);
    expect(cubit.state, isA<DesktopSidebarRefreshSucceeded>());
  });

  test("refreshes retained session inventories but reports either phase failing", () async {
    when(() => projects.refreshProjects()).thenAnswer((_) async => false);
    when(() => recent.refreshProjects(projectIds: any(named: "projectIds"))).thenAnswer((_) async => true);

    await cubit.refresh();

    verify(() => recent.refreshProjects(projectIds: any(named: "projectIds"))).called(1);
    expect(cubit.state, isA<DesktopSidebarRefreshFailed>());
  });

  test("reports failure when session inventory refresh fails", () async {
    when(() => recent.refreshProjects(projectIds: any(named: "projectIds"))).thenAnswer((_) async => false);

    await cubit.refresh();

    expect(cubit.state, const DesktopSidebarRefreshFailed());
  });

  test("reports an unexpected thrown workflow failure", () async {
    when(() => projects.refreshProjects()).thenThrow(StateError("unexpected"));

    await cubit.refresh();

    expect(cubit.state, isA<DesktopSidebarRefreshFailed>());
    verifyNever(() => recent.refreshProjects(projectIds: any(named: "projectIds")));
  });
}

ProjectListLoaded _loadedProjects({required List<String> ids}) => ProjectListState.loaded(
  projects: [
    for (final id in ids) ProjectSummary(id: id, name: id, path: "/$id", time: null),
  ],
  activityById: const {},
) as ProjectListLoaded;

class _ProjectListCubit() extends Mock implements ProjectListCubit;
class _RecentSessionsCubit() extends Mock implements RecentSessionsCubit;
