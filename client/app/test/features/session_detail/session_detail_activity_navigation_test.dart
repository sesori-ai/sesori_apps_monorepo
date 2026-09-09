import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/routing/adaptive_session_router_test_harness.dart";
import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  Future<AdaptiveSessionRouterTestHarness> setUpRouter({
    required WidgetTester tester,
    required String location,
  }) async {
    final harness = AdaptiveSessionRouterTestHarness();
    await tester.binding.setSurfaceSize(const Size(1024, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(harness.tearDown);
    await harness.setUp(
      initialLocation: location,
      currentRouteDef: AppRouteDef.sessionDetail,
      sessionsByProject: const {"p1": []},
      extraRoutes: [
        for (final route in [AppRouteDef.settings, AppRouteDef.settingsHarnesses])
          GoRoute(
            path: route.path,
            builder: (_, _) => const Scaffold(body: Text("Root cover")),
          ),
      ],
    );
    final routeSource = GoRouterRouteSource(router: harness.router);
    await GetIt.instance.unregister<RouteSource>();
    GetIt.instance.registerSingleton<RouteSource>(routeSource, dispose: (_) => routeSource.dispose());
    return harness;
  }

  SessionDetailCubit detailCubit({required WidgetTester tester}) =>
      tester.element(find.byType(SessionDetailBody)).read<SessionDetailCubit>();

  for (final detailPath in ["sessions", "archived-sessions"]) {
    testWidgets("$detailPath same-kind child suppresses parent and pop retains loaded draft", (tester) async {
      final harness = await setUpRouter(tester: tester, location: "/projects/p1/$detailPath/parent");
      await tester.pumpWidget(harness.buildApp());
      await tester.pumpAndSettle();
      final parent = detailCubit(tester: tester);
      final loadedState = parent.state;
      expect(loadedState, isA<SessionDetailLoaded>());
      expect(parent.isRouteVisible, isTrue);
      final draft = ComposerDraft.typed(text: "Retained draft");
      parent.saveComposerDraft(draft: draft);
      final viewing = GetIt.instance<SessionViewingService>() as MockSessionViewingService;
      clearInteractions(viewing);

      unawaited(harness.router.push<void>("/projects/p1/$detailPath/child"));
      await tester.pumpAndSettle();
      final child = detailCubit(tester: tester);
      expect(child, isNot(same(parent)));
      expect(parent.isRouteVisible, isFalse);
      expect(child.isRouteVisible, isTrue);
      verify(() => viewing.clearViewingSession("parent")).called(1);
      clearInteractions(viewing);

      harness.router.pop();
      await tester.pumpAndSettle();
      expect(detailCubit(tester: tester), same(parent));
      expect(parent.state, same(loadedState));
      expect(parent.composerDraft, draft);
      expect(parent.isRouteVisible, isTrue);
      expect(child.isClosed, isTrue);
      verify(() => viewing.setViewingSession("parent")).called(1);
    });
  }

  for (final cover in [
    "/settings",
    "/settings/harnesses",
    "/projects/p1/archived-sessions",
    "/projects/p1/archived-sessions/audit",
    "/projects/p1/sessions/parent/diffs",
  ]) {
    testWidgets("$cover suppresses refresh declarations and restores retained detail", (tester) async {
      final harness = await setUpRouter(tester: tester, location: "/projects/p1/sessions/parent");
      await tester.pumpWidget(harness.buildApp());
      await tester.pumpAndSettle();
      final parent = detailCubit(tester: tester);
      final draft = ComposerDraft.typed(text: "Keep while covered");
      parent.saveComposerDraft(draft: draft);
      final viewing = GetIt.instance<SessionViewingService>() as MockSessionViewingService;
      clearInteractions(viewing);

      unawaited(harness.router.push<void>(cover));
      await tester.pumpAndSettle();
      expect(parent.isRouteVisible, isFalse);
      verify(() => viewing.clearViewingSession("parent")).called(1);
      clearInteractions(viewing);
      await parent.reload();
      await tester.pumpAndSettle();
      verifyNever(() => viewing.setViewingSession("parent"));

      harness.router.pop();
      await tester.pumpAndSettle();
      expect(detailCubit(tester: tester), same(parent));
      expect(parent.state, isA<SessionDetailLoaded>());
      expect(parent.composerDraft, draft);
      expect(parent.isRouteVisible, isTrue);
      verify(() => viewing.setViewingSession("parent")).called(1);
    });
  }

  testWidgets("load completing under root Settings waits for return before viewed or analytics", (tester) async {
    final harness = await setUpRouter(tester: tester, location: "/projects/p1/sessions/parent");
    final result = Completer<SessionDetailMetadataLoadResult>();
    when(() => harness.sessionDetailLoadService.loadMetadata(sessionId: "parent")).thenAnswer((_) => result.future);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    final parent = detailCubit(tester: tester);
    unawaited(harness.router.push<void>("/settings"));
    await tester.pumpAndSettle();
    expect(parent.isRouteVisible, isFalse);
    final viewing = GetIt.instance<SessionViewingService>() as MockSessionViewingService;
    final analytics = GetIt.instance<ProductAnalyticsService>() as MockProductAnalyticsService;
    clearInteractions(viewing);
    clearInteractions(analytics);
    result.complete(SessionDetailMetadataLoadResult.found(session: testSession(id: "parent")));
    await tester.pumpAndSettle();
    expect(parent.state, isA<SessionDetailLoaded>());
    verifyNever(() => viewing.setViewingSession("parent"));
    verifyNever(
      () => analytics.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    );

    harness.router.pop();
    await tester.pumpAndSettle();
    expect(detailCubit(tester: tester), same(parent));
    verify(() => viewing.setViewingSession("parent")).called(1);
    verify(
      () => analytics.logEvent(
        event: const ProductAnalyticsEvent.sessionActivityViewed(activityState: AnalyticsActivityState.empty),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).called(1);
  });
}
