import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/routing/app_router.dart";
import "package:sesori_mobile/features/home/onboarding/bridge_onboarding.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/routing/adaptive_session_router_test_harness.dart";
import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  const projects = [
    ProjectSummary(
      id: "p1",
      name: "Project One",
      path: "/projects/p1",
      time: ProjectTime(created: 1700000000000, updated: 1700000000000),
    ),
    ProjectSummary(
      id: "p2",
      name: "Project Two",
      path: "/projects/p2",
      time: ProjectTime(created: 1700000000000, updated: 1700000000000),
    ),
  ];
  final now = DateTime.now();
  final live = adaptiveTestSession(projectId: "p1", id: "live", title: "Live record");
  final audit = adaptiveTestSession(projectId: "p1", id: "audit", title: "Archived record").copyWith(
    time: SessionTime(created: 1, updated: 2, archived: now.millisecondsSinceEpoch),
  );
  final other = adaptiveTestSession(projectId: "p2", id: "other", title: "Other archive").copyWith(
    time: SessionTime(
      created: 1,
      updated: 2,
      archived: now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
    ),
  );

  /// The router over both projects, read through the real scoped inventories.
  Future<AdaptiveSessionRouterTestHarness> setUpArchive({
    required WidgetTester tester,
    required Size size,
    required String initialLocation,
    required AppRouteDef currentRouteDef,
    required Map<String, List<Session>> sessionsByProject,
  }) async {
    final harness = AdaptiveSessionRouterTestHarness();
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(harness.tearDown);
    await harness.setUp(
      initialLocation: initialLocation,
      currentRouteDef: currentRouteDef,
      sessionsByProject: sessionsByProject,
    );
    when(() => harness.projectRepository.listProjects()).thenAnswer(
      (_) async => ApiResponse.success(const Projects(data: projects)),
    );
    return harness;
  }

  Finder tile({required String title}) => find.widgetWithText(SessionTile, title);
  Finder labelOf({required String title, required String project}) => find.descendant(
    of: tile(title: title),
    matching: find.text(project),
  );

  for (final size in [const Size(440, 956), const Size(956, 440)]) {
    testWidgets("Archived opens over the home under its filter and keeps the home through both Backs at $size", (
      tester,
    ) async {
      const opener = "/sessions";
      final harness = await setUpArchive(
        tester: tester,
        size: size,
        initialLocation: opener,
        currentRouteDef: AppRouteDef.home,
        sessionsByProject: {
          "p1": [live, audit],
          "p2": [other],
        },
      );
      await tester.pumpWidget(harness.buildApp());
      await tester.pumpAndSettle();
      GetIt.instance<SessionListFilterTracker>().select(projectId: "p1");
      await tester.pumpAndSettle();
      expect(find.text("Live record"), findsOneWidget);
      expect(find.text("Archived record"), findsNothing);
      // As Settings' Archived row pushes it.
      unawaited(harness.router.push<void>(const AppRoute.archivedSessions().buildPath()));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.toString(), "/archived-sessions");
      expect(GetIt.instance<SessionListFilterTracker>().projectId.value, "p1");
      expect(find.text("Archived sessions"), findsOneWidget);
      expect(find.text("Live record"), findsNothing);
      expect(find.text("Other archive"), findsNothing);
      expect(tile(title: "Archived record"), findsOneWidget);
      // Filtered to one project, its rows don't repeat it (D3).
      expect(labelOf(title: "Archived record", project: "Project One"), findsNothing);
      expect(find.text("Today"), findsOneWidget);
      expect(find.byKey(const Key("session-sidebar")), findsNothing);
      expect(find.byIcon(TablerRegular.plus), findsNothing);
      // A pushed page, so Back leaves it, like the other Settings pages.
      expect(find.bySemanticsLabel("Back"), findsOneWidget);
      expect(find.bySemanticsLabel("Close archived sessions"), findsNothing);
      final listElement = tester.element(find.byType(ArchivedSessionsView));
      await tester.tap(find.text("Archived record"));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, "/archived-sessions/p1/audit");
      expect(find.byIcon(TablerRegular.chevron_left), findsOneWidget);
      expect(find.byIcon(TablerRegular.git_compare), findsNothing);
      verifyNever(() => harness.projectViewingService.beginDetailClaim(projectId: any(named: "projectId")));
      await tester.tap(find.byIcon(TablerRegular.chevron_left));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(ArchivedSessionsView)), same(listElement));
      await tester.tap(find.byIcon(TablerRegular.chevron_left));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.toString(), opener);
      expect(find.text("Live record"), findsOneWidget);
      expect(find.text("Archived record"), findsNothing);
      verify(() => harness.projectViewingService.beginListClaim(projectId: "p1")).called(1);
    });
  }

  testWidgets("unfiltered, Archived lists every project's archives newest first, each naming its project", (
    tester,
  ) async {
    final harness = await setUpArchive(
      tester: tester,
      size: const Size(440, 956),
      initialLocation: const AppRoute.archivedSessions().buildPath(),
      currentRouteDef: AppRouteDef.archivedSessions,
      sessionsByProject: {
        "p1": [live, audit],
        "p2": [other],
      },
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    expect(find.text("Live record"), findsNothing);
    expect(labelOf(title: "Archived record", project: "Project One"), findsOneWidget);
    expect(labelOf(title: "Other archive", project: "Project Two"), findsOneWidget);
    expect(
      tester.getTopLeft(tile(title: "Archived record")).dy,
      lessThan(tester.getTopLeft(tile(title: "Other archive")).dy),
    );
    // Archived mode never claims a viewed project.
    verifyNever(() => harness.projectViewingService.beginListClaim(projectId: any(named: "projectId")));

    // A row opens its own project's audit record.
    await tester.tap(find.text("Other archive"));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, "/archived-sessions/p2/other");
    await tester.tap(find.byIcon(TablerRegular.chevron_left));
    await tester.pumpAndSettle();
    // Reached directly, the list's Back falls back to the home.
    await tester.tap(find.byIcon(TablerRegular.chevron_left));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.toString(), "/sessions");
  });

  testWidgets(
    "the edge swipe and system back leave the open record first, then the flow",
    (tester) async {
      const opener = "/sessions";
      final harness = await setUpArchive(
        tester: tester,
        size: const Size(440, 956),
        initialLocation: opener,
        currentRouteDef: AppRouteDef.home,
        sessionsByProject: {
          "p1": [live, audit],
        },
      );
      await tester.pumpWidget(harness.buildApp());
      await tester.pumpAndSettle();

      Future<void> openRecord() async {
        unawaited(harness.router.push<void>(const AppRoute.archivedSessions().buildPath()));
        await tester.pumpAndSettle();
        await tester.tap(find.text("Archived record"));
        await tester.pumpAndSettle();
        expect(harness.router.state.uri.path, "/archived-sessions/p1/audit");
      }

      Future<void> swipeBack() async {
        await tester.dragFrom(const Offset(5, 600), const Offset(300, 0));
        await tester.pumpAndSettle();
      }

      // The record's swipe pops only the record; the list's pops the flow.
      await openRecord();
      final listElement = tester.element(find.byType(ArchivedSessionsView, skipOffstage: false));
      await swipeBack();
      expect(harness.router.state.uri.path, "/archived-sessions");
      expect(tester.element(find.byType(ArchivedSessionsView)), same(listElement));
      await swipeBack();
      expect(harness.router.state.uri.toString(), opener);
      expect(find.text("Live record"), findsOneWidget);

      // System back takes the same two steps.
      await openRecord();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, "/archived-sessions");
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.toString(), opener);
      expect(find.text("Live record"), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets("Archived shows the computer's offline page when the relay drops", (tester) async {
    final harness = await setUpArchive(
      tester: tester,
      size: const Size(440, 956),
      initialLocation: const AppRoute.archivedSessions().buildPath(),
      currentRouteDef: AppRouteDef.archivedSessions,
      sessionsByProject: {
        "p1": [live, audit],
        "p2": [other],
      },
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    expect(tile(title: "Archived record"), findsOneWidget);

    // A torn-down relay leaves nothing reachable, so the project list goes offline.
    when(() => harness.connectionService.currentStatus).thenReturn(const ConnectionStatus.disconnected());
    harness.statusController.add(const ConnectionStatus.disconnected());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DisconnectedComputerSlivers), findsOneWidget);
    expect(tile(title: "Archived record"), findsNothing);
  });

  testWidgets("an archived row is marked unread and deleted from the list", (tester) async {
    final harness = await setUpArchive(
      tester: tester,
      size: const Size(440, 956),
      initialLocation: const AppRoute.archivedSessions().buildPath(),
      currentRouteDef: AppRouteDef.archivedSessions,
      sessionsByProject: {
        "p1": [audit],
        "p2": [other],
      },
    );
    final events = StreamController<SseEvent>.broadcast();
    addTearDown(events.close);
    when(() => harness.connectionService.events).thenAnswer((_) => events.stream);
    when(
      () => harness.sessionRepository.markSessionSeen(
        sessionId: any(named: "sessionId"),
        read: any(named: "read"),
      ),
    ).thenAnswer((_) async => ApiResponse<void>.success(null));
    when(
      () => harness.sessionRepository.deleteSession(
        sessionId: any(named: "sessionId"),
        deleteWorktree: any(named: "deleteWorktree"),
        deleteSessionFolder: any(named: "deleteSessionFolder"),
        force: any(named: "force"),
      ),
    ).thenAnswer((_) async => ApiResponse<void>.success(null));
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();

    await tester.longPress(tile(title: "Other archive"));
    await tester.pumpAndSettle();
    // Archiving is permanent, so an archived row offers neither Rename nor Archive.
    expect(find.text("Rename").hitTestable(), findsNothing);
    expect(find.text("Archive").hitTestable(), findsNothing);
    await tester.tap(find.text("Mark as unread").hitTestable());
    await tester.pumpAndSettle();
    verify(() => harness.sessionRepository.markSessionSeen(sessionId: "other", read: false)).called(1);

    await tester.longPress(tile(title: "Other archive"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Delete").hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, "Delete"));
    await tester.pumpAndSettle();
    verify(
      () => harness.sessionRepository.deleteSession(
        sessionId: "other",
        deleteWorktree: any(named: "deleteWorktree"),
        deleteSessionFolder: any(named: "deleteSessionFolder"),
        force: any(named: "force"),
      ),
    ).called(1);

    // The row leaves with the bridge's deletion event, as in every list.
    events.add(SseEvent(data: SesoriSseEvent.sessionDeleted(info: other)));
    await tester.pumpAndSettle();
    expect(find.text("Other archive"), findsNothing);
    expect(tile(title: "Archived record"), findsOneWidget);

    // Let the deletion alert expire so no timers outlive the test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets("leaving the archive retains the live detail cubit and its unsent draft", (tester) async {
    const opener = "/sessions/p1/live?name=Project+One";
    final harness = await setUpArchive(
      tester: tester,
      size: const Size(956, 440),
      initialLocation: opener,
      currentRouteDef: AppRouteDef.sessionDetail,
      sessionsByProject: {
        "p1": [live, audit],
      },
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    final openerContext = tester.element(find.byType(SessionDetailBody));
    final openerCubit = openerContext.read<SessionDetailCubit>();
    final draft = ComposerDraft.typed(text: "Unsent audit navigation test");
    openerCubit.saveComposerDraft(draft: draft);
    final viewingService = GetIt.instance<SessionViewingService>() as MockSessionViewingService;
    clearInteractions(viewingService);
    unawaited(harness.router.push<void>(const AppRoute.archivedSessions().buildPath()));
    harness.routeSource.emitRoute(AppRouteDef.archivedSessions);
    await tester.pumpAndSettle();
    verify(() => viewingService.clearViewingSession("live")).called(1);
    openerCubit.reassertViewingSession();
    verifyNever(() => viewingService.setViewingSession("live"));
    await tester.tap(find.text("Archived record"));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(TablerRegular.chevron_left));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(TablerRegular.chevron_left));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.toString(), opener);
    expect(tester.element(find.byType(SessionDetailBody)), same(openerContext));
    expect(openerCubit.composerDraft, draft);
    expect(openerCubit.isClosed, isFalse);
    clearInteractions(viewingService);
    harness.routeSource.emitRoute(AppRouteDef.sessionDetail);
    await tester.pumpAndSettle();
    verify(() => viewingService.setViewingSession("live")).called(1);
    verify(() => harness.projectViewingService.beginDetailClaim(projectId: "p1")).called(1);
  });

  testWidgets("with nothing archived the archive is empty; direct detail has only Back", (tester) async {
    final harness = await setUpArchive(
      tester: tester,
      size: const Size(440, 956),
      initialLocation: "/archived-sessions/p1/audit",
      currentRouteDef: AppRouteDef.archivedSessionDetail,
      sessionsByProject: {
        "p1": [live],
      },
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel("Close archived sessions"), findsNothing);
    expect(find.byIcon(TablerRegular.chevron_left), findsOneWidget);
    await tester.tap(find.byIcon(TablerRegular.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text("No archived sessions"), findsOneWidget);
    expect(find.text("Live record"), findsNothing);
    expect(find.bySemanticsLabel("Close archived sessions"), findsNothing);
    // With no opener under the flow, the list's Back falls back to the home.
    await tester.tap(find.byIcon(TablerRegular.chevron_left));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.toString(), "/sessions");
  });

  testWidgets("archive deletion unwinds only the matching audit navigator", (tester) async {
    const opener = "/sessions";
    final harness = await setUpArchive(
      tester: tester,
      size: const Size(440, 956),
      initialLocation: opener,
      currentRouteDef: AppRouteDef.home,
      sessionsByProject: const {"p1": []},
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    unawaited(harness.router.push<void>(const AppRoute.archivedSessions().buildPath()));
    await tester.pumpAndSettle();
    final listContext = tester.element(find.byType(ArchivedSessionsView));
    unawaited(
      harness.router.push<void>(
        const AppRoute.archivedSessionDetail(
          projectId: "p1",
          projectName: "Project One",
          sessionId: "audit",
          sessionTitle: null,
        ).buildPath(),
      ),
    );
    await tester.pumpAndSettle();
    closeDeletedArchivedSessionRoute(context: listContext, sessionId: "other");
    expect(harness.router.state.uri.toString(), contains("/audit"));
    closeDeletedArchivedSessionRoute(context: listContext, sessionId: "audit");
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, "/archived-sessions");
    await tester.tap(find.byIcon(TablerRegular.chevron_left));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.toString(), opener);
  });
}
