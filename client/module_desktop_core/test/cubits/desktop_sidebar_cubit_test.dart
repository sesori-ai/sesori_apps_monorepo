import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  late _Repository repository;
  late DesktopSidebarCubit cubit;

  setUpAll(() => registerFallbackValue(const DesktopSidebarLayout()));
  setUp(() {
    repository = _Repository();
    when(repository.readSidebarLayout).thenAnswer((_) async => const DesktopSidebarLayout());
    when(() => repository.writeSidebarLayout(layout: any(named: "layout"))).thenAnswer((_) async {});
  });
  tearDown(() => cubit.close());

  test("defaults are expanded at 260", () async {
    cubit = DesktopSidebarCubit(repository: repository);
    await pumpEventQueue();
    expect(cubit.state, const DesktopSidebarLayout());
    verifyNever(() => repository.writeSidebarLayout(layout: any(named: "layout")));
  });

  test("restores layout and clamps saved width", () async {
    when(repository.readSidebarLayout).thenAnswer(
      (_) async => const DesktopSidebarLayout(width: 900, collapsed: true, collapsedProjectIds: {"project-1"}),
    );
    cubit = DesktopSidebarCubit(repository: repository);
    await pumpEventQueue();
    expect(cubit.state, const DesktopSidebarLayout(width: 420, collapsed: true, collapsedProjectIds: {"project-1"}));
  });

  test("drag clamps in memory and persists only on commit", () async {
    cubit = DesktopSidebarCubit(repository: repository);
    await pumpEventQueue();
    cubit.resize(width: 100);
    expect(cubit.state.width, 200);
    cubit.resize(width: 600);
    expect(cubit.state.width, 420);
    cubit.resize(width: 320);
    verifyNever(() => repository.writeSidebarLayout(layout: any(named: "layout")));
    await cubit.saveLayout();
    verify(() => repository.writeSidebarLayout(layout: const DesktopSidebarLayout(width: 320))).called(1);
  });

  test("collapse and reset persist without losing the other preferences", () async {
    cubit = DesktopSidebarCubit(repository: repository);
    await pumpEventQueue();
    cubit.resize(width: 340);
    await cubit.toggleCollapsed();
    expect(cubit.state, const DesktopSidebarLayout(width: 340, collapsed: true));
    await cubit.resetWidth();
    expect(cubit.state, const DesktopSidebarLayout(collapsed: true));
    await cubit.toggleCollapsed();
    expect(cubit.state, const DesktopSidebarLayout());
    verify(() => repository.writeSidebarLayout(layout: any(named: "layout"))).called(3);
  });

  test("read failure leaves defaults and write failure keeps the live layout", () async {
    when(repository.readSidebarLayout).thenThrow(const FormatException("invalid sidebar JSON"));
    when(() => repository.writeSidebarLayout(layout: any(named: "layout"))).thenThrow(StateError("disk unavailable"));
    cubit = DesktopSidebarCubit(repository: repository);
    await pumpEventQueue();
    expect(cubit.state, const DesktopSidebarLayout());
    await cubit.toggleCollapsed();
    expect(cubit.state.collapsed, isTrue);
  });

  test("pending restore does not overwrite a user gesture", () async {
    final restore = Completer<DesktopSidebarLayout>();
    when(repository.readSidebarLayout).thenAnswer((_) => restore.future);
    cubit = DesktopSidebarCubit(repository: repository);
    cubit.resize(width: 330);
    final save = cubit.saveLayout();
    restore.complete(const DesktopSidebarLayout(width: 220));
    await save;
    expect(cubit.state.width, 330);
    verify(() => repository.writeSidebarLayout(layout: const DesktopSidebarLayout(width: 330))).called(1);
  });

  test("successive toggles serialize file writes and retain the final choice", () async {
    final firstWrite = Completer<void>();
    var writes = 0;
    when(() => repository.writeSidebarLayout(layout: any(named: "layout"))).thenAnswer((_) async {
      if (++writes == 1) await firstWrite.future;
    });
    cubit = DesktopSidebarCubit(repository: repository);
    await pumpEventQueue();
    final first = cubit.toggleCollapsed();
    final second = cubit.toggleCollapsed();
    await pumpEventQueue();
    expect(writes, 1);
    firstWrite.complete();
    await Future.wait([first, second]);
    expect(writes, 2);
    expect(cubit.state.collapsed, isFalse);
  });

  test("deferring persists the stamp, re-deferring counts as newest and the cap drops the oldest", () async {
    when(repository.readSidebarLayout).thenAnswer(
      (_) async => DesktopSidebarLayout(
        deferredSessions: {for (var index = 0; index < DesktopSidebarCubit.maxDeferredSessions; index++) "s$index": 1},
      ),
    );
    cubit = DesktopSidebarCubit(repository: repository);
    await pumpEventQueue();
    await cubit.deferSession(sessionId: "s0", updatedAt: 7);
    expect(cubit.state.deferredSessions.keys.last, "s0");
    expect(cubit.state.deferredSessions["s0"], 7);
    await cubit.deferSession(sessionId: "new", updatedAt: 9);
    expect(cubit.state.deferredSessions.length, DesktopSidebarCubit.maxDeferredSessions);
    expect(cubit.state.deferredSessions.keys.first, "s2");
    expect(cubit.state.deferredSessions.keys.last, "new");
    verify(() => repository.writeSidebarLayout(layout: cubit.state)).called(1);
  });
}

class _Repository() extends Mock implements DesktopInstanceRepository;
