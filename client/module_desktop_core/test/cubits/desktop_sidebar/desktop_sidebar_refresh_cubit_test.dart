import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  for (final outcome in DesktopSidebarRefreshOutcome.values) {
    test("refresh presents ${outcome.name} and ignores duplicate busy intent", () async {
      final workflow = _Workflow();
      final reply = Completer<DesktopSidebarRefreshOutcome>();
      when(workflow.refresh).thenAnswer((_) => reply.future);
      final cubit = DesktopSidebarRefreshCubit(service: workflow);
      addTearDown(cubit.close);
      expect(cubit.state, DesktopSidebarRefreshState.idle);
      final refresh = cubit.refresh();
      expect(cubit.state, DesktopSidebarRefreshState.refreshing);
      await cubit.refresh();
      verify(workflow.refresh).called(1);
      reply.complete(outcome);
      await refresh;
      expect(
        cubit.state,
        outcome == DesktopSidebarRefreshOutcome.succeeded
            ? DesktopSidebarRefreshState.succeeded
            : DesktopSidebarRefreshState.failed,
      );
      await cubit.refresh();
      verify(workflow.refresh).called(1);
    });
  }

  test("closing presentation cannot emit a late result or start another workflow", () async {
    final workflow = _Workflow();
    final reply = Completer<DesktopSidebarRefreshOutcome>();
    when(workflow.refresh).thenAnswer((_) => reply.future);
    final cubit = DesktopSidebarRefreshCubit(service: workflow);
    final refresh = cubit.refresh();
    await cubit.close();
    reply.complete(DesktopSidebarRefreshOutcome.succeeded);
    await refresh;
    await cubit.refresh();
    expect(cubit.state, DesktopSidebarRefreshState.refreshing);
    verify(workflow.refresh).called(1);
  });
}

class _Workflow() extends Mock implements DesktopSidebarRefreshService;
