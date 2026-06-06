import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/widgets/session_split/empty_session_detail_panel.dart";
import "package:sesori_mobile/core/widgets/session_split/session_split_breakpoints.dart";
import "package:sesori_mobile/core/widgets/session_split/session_split_route_child.dart";
import "package:sesori_mobile/core/widgets/session_split/session_split_scope.dart";
import "package:sesori_mobile/core/widgets/session_split/session_split_shell.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_zyra/module_zyra.dart";

Widget _buildTestHarness({
  required double width,
  required Widget child,
}) {
  return MaterialApp(
    theme: ThemeData(
      extensions: [ZyraDesignSystem.light],
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  group("SessionSplitShell", () {
    const listKey = Key("test-list");
    const detailKey = Key("test-detail");

    Widget shell({
      required SessionSplitRouteKind routeKind,
      required double width,
    }) {
      return _buildTestHarness(
        width: width,
        child: SessionSplitShell(
          projectId: "p1",
          projectName: "Project One",
          selectedSessionId: "s1",
          routeKind: routeKind,
          list: const SizedBox(key: listKey, child: Text("List")),
          detail: const SizedBox(key: detailKey, child: Text("Detail")),
        ),
      );
    }

    testWidgets("narrow list route shows only list pane", (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      await tester.pumpWidget(shell(routeKind: SessionSplitRouteKind.list, width: 390));
      await tester.pumpAndSettle();

      expect(find.byKey(listKey), findsOneWidget);
      expect(find.byKey(detailKey), findsNothing);
      expect(find.byKey(const Key("session-split-left-pane")), findsNothing);
      expect(find.byKey(const Key("session-split-divider")), findsNothing);
      expect(find.byKey(const Key("session-split-right-pane")), findsNothing);
    });

    testWidgets("narrow detail route shows only detail pane", (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      await tester.pumpWidget(shell(routeKind: SessionSplitRouteKind.detail, width: 390));
      await tester.pumpAndSettle();

      expect(find.byKey(listKey), findsNothing);
      expect(find.byKey(detailKey), findsOneWidget);
    });

    testWidgets("narrow diffs route shows only detail pane", (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      await tester.pumpWidget(shell(routeKind: SessionSplitRouteKind.diffs, width: 390));
      await tester.pumpAndSettle();

      expect(find.byKey(listKey), findsNothing);
      expect(find.byKey(detailKey), findsOneWidget);
    });

    testWidgets("wide layout renders left pane, divider, and right pane", (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      await tester.pumpWidget(shell(routeKind: SessionSplitRouteKind.detail, width: 1024));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("session-split-left-pane")), findsOneWidget);
      expect(find.byKey(const Key("session-split-divider")), findsOneWidget);
      expect(find.byKey(const Key("session-split-right-pane")), findsOneWidget);
      expect(find.byKey(listKey), findsOneWidget);
      expect(find.byKey(detailKey), findsOneWidget);
    });

    testWidgets("wide list route shows list and placeholder in right pane", (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      await tester.pumpWidget(shell(routeKind: SessionSplitRouteKind.list, width: 1024));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("session-split-left-pane")), findsOneWidget);
      expect(find.byKey(const Key("session-split-right-pane")), findsOneWidget);
      expect(find.byKey(listKey), findsOneWidget);
      expect(find.byKey(detailKey), findsOneWidget);
    });

    testWidgets("left panel width is clamped between min and max", (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      await tester.pumpWidget(shell(routeKind: SessionSplitRouteKind.detail, width: 1024));
      await tester.pumpAndSettle();

      final leftPane = tester.widget<SizedBox>(
        find.byKey(const Key("session-split-left-pane")),
      );
      expect(leftPane.width, greaterThanOrEqualTo(minListPanelWidth));
      expect(leftPane.width, lessThanOrEqualTo(maxListPanelWidth));
    });

    testWidgets("left panel width does not exceed max ratio", (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(shell(routeKind: SessionSplitRouteKind.detail, width: 1200));
      await tester.pumpAndSettle();

      final leftPane = tester.widget<SizedBox>(
        find.byKey(const Key("session-split-left-pane")),
      );
      expect(leftPane.width, lessThanOrEqualTo(1200 * maxListPanelRatio));
    });

    testWidgets("narrow scope exposes isSplit=false", (tester) async {
      bool? capturedIsSplit;

      await tester.binding.setSurfaceSize(const Size(390, 800));
      await tester.pumpWidget(
        _buildTestHarness(
          width: 390,
          child: SessionSplitShell(
            projectId: "p1",
            routeKind: SessionSplitRouteKind.list,
            list: Builder(
              builder: (context) {
                capturedIsSplit = SessionSplitScope.of(context).isSplit;
                return const SizedBox();
              },
            ),
            detail: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedIsSplit, isFalse);
    });

    testWidgets("wide scope exposes isSplit=true", (tester) async {
      bool? capturedIsSplit;

      await tester.binding.setSurfaceSize(const Size(1024, 800));
      await tester.pumpWidget(
        _buildTestHarness(
          width: 1024,
          child: SessionSplitShell(
            projectId: "p1",
            routeKind: SessionSplitRouteKind.list,
            list: Builder(
              builder: (context) {
                capturedIsSplit = SessionSplitScope.of(context).isSplit;
                return const SizedBox();
              },
            ),
            detail: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedIsSplit, isTrue);
    });

    testWidgets("scope exposes projectId and selectedSessionId", (tester) async {
      String? capturedProjectId;
      String? capturedSessionId;

      await tester.binding.setSurfaceSize(const Size(1024, 800));
      await tester.pumpWidget(
        _buildTestHarness(
          width: 1024,
          child: SessionSplitShell(
            projectId: "p1",
            selectedSessionId: "s1",
            routeKind: SessionSplitRouteKind.list,
            list: Builder(
              builder: (context) {
                final scope = SessionSplitScope.of(context);
                capturedProjectId = scope.projectId;
                capturedSessionId = scope.selectedSessionId;
                return const SizedBox();
              },
            ),
            detail: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedProjectId, "p1");
      expect(capturedSessionId, "s1");
    });

    testWidgets("wide detail route shows exactly one app bar in right panel", (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      await tester.pumpWidget(
        _buildTestHarness(
          width: 1024,
          child: SessionSplitShell(
            projectId: "p1",
            routeKind: SessionSplitRouteKind.detail,
            list: const SizedBox(),
            detail: Scaffold(
              appBar: AppBar(title: const Text("Detail")),
              body: const Text("Detail body"),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rightPane = find.byKey(const Key("session-split-right-pane"));
      final appBarsInRightPane = find.descendant(of: rightPane, matching: find.byType(AppBar));
      expect(appBarsInRightPane, findsOneWidget);
      expect(find.text("Detail"), findsOneWidget);
    });

    testWidgets("wide diffs route shows exactly one app bar in right panel", (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      await tester.pumpWidget(
        _buildTestHarness(
          width: 1024,
          child: SessionSplitShell(
            projectId: "p1",
            routeKind: SessionSplitRouteKind.diffs,
            list: const SizedBox(),
            detail: Scaffold(
              appBar: AppBar(title: const Text("Diffs")),
              body: const Text("Diffs body"),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rightPane = find.byKey(const Key("session-split-right-pane"));
      final appBarsInRightPane = find.descendant(of: rightPane, matching: find.byType(AppBar));
      expect(appBarsInRightPane, findsOneWidget);
      expect(find.text("Diffs"), findsOneWidget);
    });

    testWidgets("shell itself does not add an outer app bar", (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 800));
      await tester.pumpWidget(
        _buildTestHarness(
          width: 1024,
          child: const SessionSplitShell(
            projectId: "p1",
            routeKind: SessionSplitRouteKind.detail,
            list: SizedBox(),
            detail: SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
    });
  });

  group("SessionSplitRouteChild", () {
    testWidgets("carries routeKind, route, and child", (tester) async {
      const route = AppRoute.sessions(projectId: "p1", projectName: null);

      await tester.pumpWidget(
        const MaterialApp(
          home: SessionSplitRouteChild(
            routeKind: SessionSplitRouteKind.list,
            route: route,
            child: Text("Hello"),
          ),
        ),
      );

      final routeChild = tester.widget<SessionSplitRouteChild>(
        find.byType(SessionSplitRouteChild),
      );
      expect(routeChild.routeKind, SessionSplitRouteKind.list);
      expect(routeChild.route, route);
      expect(find.text("Hello"), findsOneWidget);
    });
  });

  group("EmptySessionDetailPanel", () {
    testWidgets("renders with stable key and localized text", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [ZyraDesignSystem.light],
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EmptySessionDetailPanel(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key("empty-session-detail-panel")), findsOneWidget);
      expect(find.text("Select a session"), findsOneWidget);
      expect(find.text("Choose a session from the list to view details"), findsOneWidget);
    });
  });
}
