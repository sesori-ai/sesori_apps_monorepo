import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  late _RefreshOrchestrator orchestrator;
  late DesktopSidebarRefreshCubit cubit;

  setUp(() {
    orchestrator = _RefreshOrchestrator();
    when(orchestrator.refresh).thenAnswer((_) async => DesktopSidebarRefreshResult.succeeded);
    cubit = DesktopSidebarRefreshCubit(refreshOperation: orchestrator);
  });

  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  test("maps the coordinated result to presentation state", () async {
    final states = expectLater(
      cubit.stream,
      emitsInOrder([const DesktopSidebarRefreshInProgress(), const DesktopSidebarRefreshSucceeded()]),
    );

    await cubit.refresh();
    await states;

    verify(orchestrator.refresh).called(1);
  });

  test("maps a failed result", () async {
    when(orchestrator.refresh).thenAnswer((_) async => DesktopSidebarRefreshResult.failed);

    await cubit.refresh();

    expect(cubit.state, const DesktopSidebarRefreshFailed());
  });

  test("coalesces duplicate intent while refreshing", () async {
    final result = Completer<DesktopSidebarRefreshResult>();
    when(orchestrator.refresh).thenAnswer((_) => result.future);
    final first = cubit.refresh();
    final second = cubit.refresh();
    result.complete(DesktopSidebarRefreshResult.succeeded);
    await Future.wait([first, second]);

    verify(orchestrator.refresh).called(1);
    expect(cubit.state, const DesktopSidebarRefreshSucceeded());
  });

  test("does not publish after close", () async {
    final result = Completer<DesktopSidebarRefreshResult>();
    when(orchestrator.refresh).thenAnswer((_) => result.future);
    final pending = cubit.refresh();
    await cubit.close();
    result.complete(DesktopSidebarRefreshResult.succeeded);

    await pending;

    expect(cubit.isClosed, isTrue);
  });
}

class _RefreshOrchestrator() extends Mock implements DesktopSidebarRefreshOperation;
