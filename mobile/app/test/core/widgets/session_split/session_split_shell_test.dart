import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/widgets/sesori_background_widget.dart";
import "package:sesori_mobile/core/widgets/session_split/empty_session_detail_panel.dart";
import "package:sesori_mobile/core/widgets/session_split/session_split_breakpoints.dart";
import "package:sesori_mobile/core/widgets/session_split/session_split_scope.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_zyra/module_zyra.dart";

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
    testWidgets("renders with stable key and localized text", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [ZyraDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EmptySessionDetailPanel(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("empty-session-detail-panel")), findsOneWidget);
      expect(find.byType(Material), findsWidgets);
      expect(find.byType(SesoriBackgroundWidget), findsOneWidget);
      expect(find.text("Select a session"), findsOneWidget);
      expect(find.text("Choose a session from the list to view details"), findsOneWidget);
    });
  });
}
