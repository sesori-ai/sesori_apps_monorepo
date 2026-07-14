import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/widgets/connection_banner.dart";
import "package:sesori_mobile/core/widgets/sesori_background_widget.dart";
import "package:sesori_mobile/core/widgets/session_split/empty_session_detail_panel.dart";
import "package:sesori_mobile/core/widgets/session_split/session_split_breakpoints.dart";
import "package:sesori_mobile/core/widgets/session_split/session_split_scope.dart";
import "package:sesori_mobile/features/new_session/new_session_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../helpers/test_helpers.dart";
import "../../routing/adaptive_session_router_test_harness.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("SessionSplitShell", () {
    testWidgets("narrow route exposes isSplit=false and hides split panes", (tester) async {
      final harness = AdaptiveSessionRouterTestHarness();
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(harness.tearDown);
      await harness.setUp(
        initialLocation: "/projects/p1/sessions",
        currentRouteDef: AppRouteDef.sessions,
        sessionsByProject: {
          "p1": [adaptiveTestSession(projectId: "p1", id: "s1", title: "Session One")],
        },
      );

      await tester.pumpWidget(harness.buildApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("session-split-left-pane")), findsNothing);
      expect(find.byKey(const Key("session-split-divider")), findsNothing);
      expect(find.byKey(const Key("session-split-right-pane")), findsNothing);
      final scope = SessionSplitScope.of(tester.element(find.text("Session One")));
      expect(scope.isSplit, isFalse);
    });

    testWidgets("wide layout renders left pane, divider, and right pane", (tester) async {
      final harness = AdaptiveSessionRouterTestHarness();
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(harness.tearDown);
      await harness.setUp(
        initialLocation: "/projects/p1/sessions/session-1?title=Session+One&readOnly=false",
        currentRouteDef: AppRouteDef.sessionDetail,
        sessionsByProject: {
          "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
        },
      );

      await tester.pumpWidget(harness.buildApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("session-split-left-pane")), findsOneWidget);
      expect(find.byKey(const Key("session-split-divider")), findsOneWidget);
      expect(find.byKey(const Key("session-split-right-pane")), findsOneWidget);
      expect(find.byKey(const ValueKey("session-detail-session-1")), findsOneWidget);
      final scope = SessionSplitScope.of(tester.element(find.byKey(const ValueKey("session-detail-session-1"))));
      expect(scope.isSplit, isTrue);
    });

    testWidgets("wide list route shows placeholder in right pane", (tester) async {
      final harness = AdaptiveSessionRouterTestHarness();
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(harness.tearDown);
      await harness.setUp(
        initialLocation: "/projects/p1/sessions",
        currentRouteDef: AppRouteDef.sessions,
        sessionsByProject: {
          "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
        },
      );

      await tester.pumpWidget(harness.buildApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("session-split-left-pane")), findsOneWidget);
      expect(find.byKey(const Key("session-split-right-pane")), findsOneWidget);
      expect(find.byType(EmptySessionDetailPanel), findsOneWidget);
    });

    testWidgets("left panel width is clamped between min and max", (tester) async {
      final harness = AdaptiveSessionRouterTestHarness();
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(harness.tearDown);
      await harness.setUp(
        initialLocation: "/projects/p1/sessions",
        currentRouteDef: AppRouteDef.sessions,
        sessionsByProject: const {"p1": []},
      );

      await tester.pumpWidget(harness.buildApp());
      await tester.pumpAndSettle();

      final leftPane = tester.widget<SizedBox>(find.byKey(const Key("session-split-left-pane")));
      expect(leftPane.width, greaterThanOrEqualTo(minListPanelWidth));
      expect(leftPane.width, lessThanOrEqualTo(maxListPanelWidth));
    });

    testWidgets("wide mode presents snackbars on the shell scaffold spanning both panes", (tester) async {
      final harness = AdaptiveSessionRouterTestHarness();
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(harness.tearDown);
      await harness.setUp(
        initialLocation: "/projects/p1/sessions",
        currentRouteDef: AppRouteDef.sessions,
        sessionsByProject: {
          "p1": [adaptiveTestSession(projectId: "p1", id: "s1", title: "Session One")],
        },
      );

      await tester.pumpWidget(harness.buildApp());
      await tester.pumpAndSettle();

      // Trigger a snackbar from a left-pane context, like the "session
      // deleted" snackbar shown after deleting a session from the list.
      final leftPaneContext = tester.element(find.text("Session One"));
      ScaffoldMessenger.of(leftPaneContext).showSnackBar(
        const SnackBar(content: Text("Session deleted")),
      );
      await tester.pumpAndSettle();

      // Exactly one snackbar, attached to the shell scaffold — spanning the
      // full shell width instead of being confined to the right pane.
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(SnackBar),
          matching: find.byKey(const Key("session-split-scaffold")),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(SnackBar)).width, 1024);
    });

    testWidgets("opening another session while a new session is sending does not crash", (tester) async {
      final harness = AdaptiveSessionRouterTestHarness();
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(harness.tearDown);
      // Start from an already-open session detail (the failing real path). The
      // underlying detail page shares a pattern-based page key, so swapping
      // s1 -> s2 updates it in place while the pushed new-session page becomes
      // the exiting route that Flutter pops during build.
      await harness.setUp(
        initialLocation: "/projects/p1/sessions/s1?title=Session+One&readOnly=false&name=Project+One",
        currentRouteDef: AppRouteDef.sessionDetail,
        sessionsByProject: {
          "p1": [
            adaptiveTestSession(projectId: "p1", id: "s1", title: "Session One"),
            adaptiveTestSession(projectId: "p1", id: "s2", title: "Session Two"),
          ],
        },
      );

      // Creation stays in flight: the user navigates away before it resolves.
      final createCompleter = Completer<ApiResponse<Session>>();
      addTearDown(() {
        if (!createCompleter.isCompleted) {
          createCompleter.complete(ApiResponse.error(ApiError.generic()));
        }
      });
      when(
        () => harness.sessionRepository.createSessionWithMessage(
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) => createCompleter.future);

      await tester.pumpWidget(harness.buildApp());
      await tester.pumpAndSettle();

      final leftPane = find.byKey(const Key("session-split-left-pane"));
      final loc = AppLocalizations.of(
        tester.element(find.descendant(of: leftPane, matching: find.text("Session Two"))),
      )!;

      // Open the new-session composer — pushed imperatively onto the pane
      // navigator (mirrors the list pane's "New session" button).
      await tester.tap(find.descendant(of: leftPane, matching: find.byIcon(Icons.add)));
      await tester.pumpAndSettle();
      expect(find.byType(NewSessionScreen), findsOneWidget);

      // Start sending; creation is now in flight. Scope to the composer — the
      // session-detail route behind the pushed overlay also has a prompt field.
      final newSession = find.byType(NewSessionScreen);
      await tester.enterText(find.descendant(of: newSession, matching: find.byType(EditableText)), "do the thing");
      await tester.tap(find.descendant(of: newSession, matching: find.byIcon(Icons.send)), warnIfMissed: false);
      await tester.pump();
      expect(find.byKey(const Key("new_session_loading_overlay")), findsOneWidget);

      // Open a different existing session from the list. go_router swaps the
      // underlying detail in place and pops the pushed new-session page during
      // the Navigator's build phase, invoking PopScope.onPopInvokedWithResult
      // mid-build — where calling showSnackBar directly throws
      // "showSnackBar() called during build".
      await tester.tap(find.descendant(of: leftPane, matching: find.text("Session Two")));
      await tester.pump();

      // The launching-in-background snackbar must be deferred past the current
      // frame, not thrown during build.
      expect(tester.takeException(), isNull);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byType(NewSessionScreen), findsNothing);
      expect(find.text(loc.newSessionLaunchingInBackground), findsOneWidget);
    });

    testWidgets("wide to narrow resize preserves the same SessionListCubit instance", (tester) async {
      final harness = AdaptiveSessionRouterTestHarness();
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(harness.tearDown);
      await harness.setUp(
        initialLocation: "/projects/p1/sessions",
        currentRouteDef: AppRouteDef.sessions,
        sessionsByProject: {
          "p1": [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
        },
      );

      await tester.pumpWidget(harness.buildApp());
      await tester.pumpAndSettle();
      final before = BlocProvider.of<SessionListCubit>(tester.element(find.text("Session One")));

      await tester.binding.setSurfaceSize(const Size(390, 800));
      await tester.pumpAndSettle();
      final after = BlocProvider.of<SessionListCubit>(tester.element(find.text("Session One")));

      expect(identical(before, after), isTrue);
    });
  });

  group("EmptySessionDetailPanel", () {
    Future<void> pumpPanel(WidgetTester tester, {required ConnectionOverlayState overlayState}) async {
      final cubit = StubConnectionOverlayCubit(initialState: overlayState);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        BlocProvider<ConnectionOverlayCubit>.value(
          value: cubit,
          child: MaterialApp(
            theme: ThemeData(extensions: [PregoDesignSystem.light]),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const EmptySessionDetailPanel(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("renders with stable key and localized text", (tester) async {
      await pumpPanel(tester, overlayState: const ConnectionOverlayState.hidden());

      expect(find.byKey(const Key("empty-session-detail-panel")), findsOneWidget);
      expect(find.byType(Material), findsWidgets);
      expect(find.byType(SesoriBackgroundWidget), findsOneWidget);
      expect(find.text("Select a session"), findsOneWidget);
      expect(find.text("Choose a session from the list to view details"), findsOneWidget);
    });

    testWidgets("hides the connection banner while the bridge is reachable", (tester) async {
      await pumpPanel(tester, overlayState: const ConnectionOverlayState.hidden());

      expect(find.byType(ConnectionBanner), findsNothing);
    });

    testWidgets("surfaces the bridge-offline banner so the wide list route is not left silent", (tester) async {
      // The wide split's list pane has no glass top-nav banner slot, so this
      // placeholder is the only offline-messaging host when no session is
      // selected. Without it the bridge-offline state would show nothing here.
      await pumpPanel(tester, overlayState: const ConnectionOverlayState.bridgeOffline());

      expect(find.byType(ConnectionBanner), findsOneWidget);
    });
  });
}
