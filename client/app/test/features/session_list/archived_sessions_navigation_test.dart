import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/routing/app_router.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/routing/adaptive_session_router_test_harness.dart";
import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  for (final size in [const Size(440, 956), const Size(956, 440)]) {
    testWidgets("archive modal retains opener and list through Back and X at $size", (tester) async {
      final harness = AdaptiveSessionRouterTestHarness();
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(harness.tearDown);
      const opener = "/projects/p1/sessions?name=Project+One";
      final archived = adaptiveTestSession(projectId: "p1", id: "audit", title: "Archived record").copyWith(
        time: SessionTime(created: 1, updated: 2, archived: DateTime.now().millisecondsSinceEpoch),
      );
      await harness.setUp(
        initialLocation: opener,
        currentRouteDef: AppRouteDef.sessions,
        sessionsByProject: {
          "p1": [adaptiveTestSession(projectId: "p1", id: "live", title: "Live record"), archived],
        },
      );
      await tester.pumpWidget(harness.buildApp());
      await tester.pumpAndSettle();
      expect(find.text("Live record"), findsOneWidget);
      expect(find.text("Archived record"), findsNothing);
      final entry = size.width > size.height
          ? find.byIcon(Icons.archive_outlined)
          : find.bySemanticsLabel("Show archived");
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text("Archived tasks"), findsOneWidget);
      expect(find.text("Live record"), findsNothing);
      expect(find.text("Archived record"), findsOneWidget);
      expect(find.text("Today"), findsOneWidget);
      expect(find.byKey(const Key("session-split-left-pane")), findsNothing);
      expect(find.byIcon(TablerRegular.plus), findsNothing);
      final listElement = tester.element(find.byType(ArchivedSessionsView));
      await tester.tap(find.text("Archived record"));
      await tester.pumpAndSettle();
      expect(find.byIcon(TablerRegular.chevron_left), findsOneWidget);
      expect(find.byIcon(TablerRegular.git_compare), findsNothing);
      expect(find.bySemanticsLabel("Close archived sessions"), findsOneWidget);
      verifyNever(() => harness.projectViewingService.beginDetailClaim(projectId: any(named: "projectId")));
      await tester.tap(find.byIcon(TablerRegular.chevron_left));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(ArchivedSessionsView)), same(listElement));
      await tester.tap(find.text("Archived record"));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel("Close archived sessions"));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.toString(), opener);
      expect(find.text("Live record"), findsOneWidget);
      expect(find.text("Archived record"), findsNothing);
      verify(() => harness.projectViewingService.beginListClaim(projectId: "p1")).called(1);
    });
  }

  testWidgets("closing audit detail retains the live detail cubit and its unsent draft", (tester) async {
    final harness = AdaptiveSessionRouterTestHarness();
    await tester.binding.setSurfaceSize(const Size(956, 440));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(harness.tearDown);
    const opener = "/projects/p1/sessions/live?name=Project+One";
    final archived = adaptiveTestSession(
      projectId: "p1",
      id: "audit",
      title: "Archived record",
    ).copyWith(time: const SessionTime(created: 1, updated: 2, archived: 3));
    await harness.setUp(
      initialLocation: opener,
      currentRouteDef: AppRouteDef.sessionDetail,
      sessionsByProject: {
        "p1": [archived],
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
    await tester.tap(find.byIcon(Icons.archive_outlined));
    harness.routeSource.emitRoute(AppRouteDef.archivedSessions);
    await tester.pumpAndSettle();
    verify(() => viewingService.clearViewingSession("live")).called(1);
    openerCubit.reassertViewingSession();
    verifyNever(() => viewingService.setViewingSession("live"));
    await tester.tap(find.text("Archived record"));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel("Close archived sessions"));
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

  testWidgets("active-only project has an empty archive; direct detail has Back and X", (tester) async {
    final harness = AdaptiveSessionRouterTestHarness();
    addTearDown(harness.tearDown);
    await harness.setUp(
      initialLocation: "/projects/p1/archived-sessions/audit",
      currentRouteDef: AppRouteDef.archivedSessionDetail,
      sessionsByProject: {
        "p1": [adaptiveTestSession(projectId: "p1", id: "live", title: "Live record")],
      },
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel("Close archived sessions"), findsOneWidget);
    await tester.tap(find.byIcon(TablerRegular.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text("No archived sessions"), findsOneWidget);
    expect(find.text("Live record"), findsNothing);
    expect(find.byIcon(TablerRegular.chevron_left), findsNothing);
    await tester.tap(find.bySemanticsLabel("Close archived sessions"));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.toString(), "/projects");
  });

  testWidgets("archive deletion unwinds only the matching audit navigator", (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 956));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final harness = AdaptiveSessionRouterTestHarness();
    addTearDown(harness.tearDown);
    const opener = "/projects/p1/sessions?name=Project+One";
    await harness.setUp(
      initialLocation: opener,
      currentRouteDef: AppRouteDef.sessions,
      sessionsByProject: const {"p1": []},
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    unawaited(
      harness.router.push<void>(
        const AppRoute.archivedSessions(projectId: "p1", projectName: "Project One").buildPath(),
      ),
    );
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
    closeDeletedArchivedSessionRoute(context: listContext, projectId: "other", sessionId: "audit");
    closeDeletedArchivedSessionRoute(context: listContext, projectId: "p1", sessionId: "other");
    expect(harness.router.state.uri.toString(), contains("/audit"));
    closeDeletedArchivedSessionRoute(context: listContext, projectId: "p1", sessionId: "audit");
    await tester.pumpAndSettle();
    expect(Uri.parse(harness.router.state.uri.toString()).path, "/projects/p1/archived-sessions");
    await tester.tap(find.bySemanticsLabel("Close archived sessions"));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.toString(), opener);
  });
}
