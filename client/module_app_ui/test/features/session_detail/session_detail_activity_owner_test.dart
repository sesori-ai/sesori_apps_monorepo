import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";

class _MockSessionDetailCubit() extends Mock implements SessionDetailCubit;

class _MockRouteSource() extends Mock implements RouteSource;

class _MockLifecycleSource() extends Mock implements LifecycleSource;

class _MockProductAnalyticsService() extends Mock implements ProductAnalyticsService;

const _loaded = SessionDetailState.loaded(
  interaction: SessionInteractionState.available(displayName: "Claude Code", refreshError: null),
  messages: [],
  olderMessagesCursor: null,
  streamingText: {},
  sessionStatus: SessionStatus.idle(),
  pendingQuestions: [],
  pendingPermissions: [],
  sessionTitle: null,
  session: testConstSession,
  pluginId: "opencode",
  supportsPromptAttachments: false,
  assistantAgentModel: null,
  children: [],
  childStatuses: {},
  isRootSession: true,
  isArchived: false,
  queuedMessages: [],
  sendingSubmission: null,
  availableAgents: [],
  availableProviders: [],
  availableCommands: [],
  selectedAgent: "build",
  selectedAgentModel: null,
  fastMode: false,
  stagedCommand: null,
  isRefreshing: false,
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const ProductAnalyticsEvent.sessionActivityViewed(activityState: AnalyticsActivityState.empty),
    );
    registerFallbackValue(DateTime.utc(2026));
  });

  for (final (expectedRoute, nested) in [
    (AppRouteDef.sessionDetail, false),
    (AppRouteDef.archivedSessionDetail, false),
    (AppRouteDef.sessionDetail, true),
    (AppRouteDef.archivedSessionDetail, true),
  ]) {
    testWidgets("$expectedRoute gates activity and disposes only its listeners (nested: $nested)", (tester) async {
      final cubit = _MockSessionDetailCubit();
      final routeSource = _MockRouteSource();
      final lifecycleSource = _MockLifecycleSource();
      final analytics = _MockProductAnalyticsService();
      final routes = BehaviorSubject<AppRouteDef?>.seeded(
        expectedRoute == AppRouteDef.sessionDetail ? AppRouteDef.archivedSessionDetail : AppRouteDef.sessionDetail,
      );
      final lifecycle = BehaviorSubject.seeded(LifecycleState.resumed);
      final states = StreamController<SessionDetailState>.broadcast();
      final analyticsStates = BehaviorSubject.seeded(ProductAnalyticsState.initial);
      addTearDown(routes.close);
      addTearDown(lifecycle.close);
      addTearDown(states.close);
      addTearDown(analyticsStates.close);
      when(() => cubit.state).thenReturn(_loaded);
      when(() => cubit.stream).thenAnswer((_) => states.stream);
      when(() => routeSource.currentRouteStream).thenAnswer((_) => routes.stream);
      when(() => lifecycleSource.lifecycleStateStream).thenAnswer((_) => lifecycle.stream);
      when(() => analytics.state).thenAnswer((_) => analyticsStates.value);
      when(() => analytics.stateStream).thenAnswer((_) => analyticsStates.stream);
      var events = 0;
      when(
        () => analytics.logEvent(
          event: any(named: "event"),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      ).thenAnswer((_) async {
        events++;
        return AnalyticsDeliveryResult.acceptedBySdk;
      });
      final visibility = <bool>[];
      when(() => cubit.setRouteVisible(isVisible: any(named: "isVisible"))).thenAnswer((invocation) {
        visibility.add(invocation.namedArguments[#isVisible]! as bool);
      });

      final rootNavigator = GlobalKey<NavigatorState>();
      final owner = SessionDetailActivityOwner(
        routeSource: routeSource,
        lifecycleSource: lifecycleSource,
        productAnalyticsService: analytics,
        expectedDetailRoute: expectedRoute,
        child: const SizedBox(),
      );
      await tester.pumpWidget(
        BlocProvider<SessionDetailCubit>.value(
          value: cubit,
          child: MaterialApp(
            navigatorKey: rootNavigator,
            home: nested
                ? Builder(
                    builder: (context) => SessionDetailRouteVisibility(
                      isVisible: ModalRoute.isCurrentOf(context) ?? false,
                      child: Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => owner)),
                    ),
                  )
                : owner,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(visibility.last, isFalse);
      expect(events, 0);
      expect(routes.hasListener, isTrue);
      expect(states.hasListener, isTrue);
      expect(lifecycle.hasListener, isTrue);
      expect(analyticsStates.hasListener, isTrue);

      // App lifecycle remains the analytics listener's concern, not a second
      // visibility calculation in the Flutter owner.
      lifecycle.add(LifecycleState.hidden);
      routes.add(expectedRoute);
      await tester.pumpAndSettle();
      expect(visibility.last, isTrue);
      expect(events, 0);
      visibility.clear();
      lifecycle.add(LifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(visibility, isEmpty);
      expect(events, 1);

      routes.add(AppRouteDef.settings);
      await tester.pumpAndSettle();
      expect(visibility.last, isFalse);
      routes.add(expectedRoute);
      await tester.pumpAndSettle();
      expect(visibility.last, isTrue);
      expect(events, 1); // Existing analytics deduplication survives cover/return.

      final ownerElement = tester.element(find.byType(SessionDetailActivityOwner));
      showDialog<void>(
        context: ownerElement,
        builder: (_) => const Dialog(child: Text("root popup")),
      );
      await tester.pumpAndSettle();
      expect(routeSource.currentRoute, expectedRoute);
      expect(ModalRoute.of(ownerElement)?.isCurrent, nested);
      expect(visibility.last, isFalse);
      expect(events, 1);
      rootNavigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(visibility.last, isTrue);
      expect(tester.element(find.byType(SessionDetailActivityOwner)), same(ownerElement));
      expect(events, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(routes.hasListener, isFalse);
      expect(states.hasListener, isFalse);
      expect(lifecycle.hasListener, isFalse);
      expect(analyticsStates.hasListener, isFalse);
      verifyNever(cubit.close); // The shell/provider still owns the cubit.
      visibility.clear();
      routes.add(AppRouteDef.settings);
      lifecycle.add(LifecycleState.resumed);
      states.add(_loaded);
      analyticsStates.add(ProductAnalyticsState.initial);
      await tester.pumpAndSettle();
      expect(visibility, isEmpty);
      expect(events, 1);
    });
  }
}
