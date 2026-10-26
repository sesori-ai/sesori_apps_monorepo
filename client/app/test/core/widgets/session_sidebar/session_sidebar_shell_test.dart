import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/new_session/new_session_screen.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../helpers/test_helpers.dart";
import "../../routing/adaptive_session_router_test_harness.dart";

const _sidebar = Key("session-sidebar");
const _content = Key("session-sidebar-content");
const _detail = ValueKey("session-detail-session-1");
const _margin = FloatingSidebarPanel.margin;

/// The open panel's width plus its margins on either side.
const _sidebarExtent = 320 + 2 * _margin;

void main() {
  setUpAll(registerAllFallbackValues);

  Future<AdaptiveSessionRouterTestHarness> pumpShell(
    WidgetTester tester, {
    required Size size,
    required String initialLocation,
    required AppRouteDef currentRouteDef,
    List<Session>? sessions,
    Map<String, List<FileDiff>> diffsBySession = const {},
  }) async {
    final harness = AdaptiveSessionRouterTestHarness();
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(harness.tearDown);
    await harness.setUp(
      initialLocation: initialLocation,
      currentRouteDef: currentRouteDef,
      sessionsByProject: {
        "p1": sessions ?? [adaptiveTestSession(projectId: "p1", id: "session-1", title: "Session One")],
      },
      diffsBySession: diffsBySession,
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pumpAndSettle();
    return harness;
  }

  void verifyPaneVisible(AdaptiveSessionRouterTestHarness harness, {required bool isVisible, required int times}) {
    verify(
      () => harness.projectViewingService.setWideListPaneVisible(
        claim: any(named: "claim"),
        isVisible: isVisible,
      ),
    ).called(times);
  }

  Finder inSidebar(Finder finder) => find.descendant(of: find.byKey(_sidebar), matching: finder);
  Finder inContent(Finder finder) => find.descendant(of: find.byKey(_content), matching: finder);

  group("SessionSidebarShell", () {
    testWidgets("below 700 pt the home fills the screen without a sidebar", (tester) async {
      final harness = await pumpShell(
        tester,
        size: const Size(699, 800),
        initialLocation: "/sessions",
        currentRouteDef: AppRouteDef.home,
      );

      expect(find.byKey(_sidebar), findsNothing);
      expect(find.text("Session One"), findsOneWidget);
      expect(SessionSidebarShell.layoutOf(tester.element(find.text("Session One"))), SessionShellLayout.pages);
      verifyNever(
        () => harness.projectViewingService.setWideListPaneVisible(claim: any(named: "claim"), isVisible: true),
      );
    });

    testWidgets("from 700 pt the open session shows beside the sidebar, highlighted", (tester) async {
      final harness = await pumpShell(
        tester,
        size: const Size(700, 800),
        initialLocation: "/sessions/p1/session-1?title=Session+One&readOnly=false",
        currentRouteDef: AppRouteDef.sessionDetail,
      );

      expect(inContent(find.byKey(_detail)), findsOneWidget);
      expect(SessionSidebarShell.layoutOf(tester.element(find.byKey(_detail))), SessionShellLayout.pane);
      final tile = tester.widget<SessionTile>(inSidebar(find.byType(SessionTile)));
      expect(tile.selected, isTrue);
      verifyPaneVisible(harness, isVisible: true, times: 1);
    });

    testWidgets("with no session open the pane is a new session in the default project", (tester) async {
      await pumpShell(
        tester,
        size: const Size(1024, 800),
        initialLocation: "/sessions",
        currentRouteDef: AppRouteDef.home,
      );

      expect(inSidebar(find.text("Session One")), findsOneWidget);
      expect(inSidebar(find.byKey(const Key("home-new-session"))), findsOneWidget);
      expect(inContent(find.byType(NewSessionView)), findsOneWidget);
      expect(tester.widget<NewSessionView>(find.byType(NewSessionView)).projectId, "p1");
      expect(tester.widget<SessionTile>(inSidebar(find.byType(SessionTile))).selected, isFalse);
    });

    testWidgets("with no default project the pane asks for one, with nothing selected", (tester) async {
      await pumpShell(
        tester,
        size: const Size(1024, 800),
        initialLocation: "/sessions",
        currentRouteDef: AppRouteDef.home,
        sessions: const [],
      );

      expect(inContent(find.byType(NewSessionProjectPrompt)), findsOneWidget);
      expect(find.byType(NewSessionView), findsNothing);
      // At rest the pane waits for a tap rather than opening the picker.
      expect(find.text("Open folder…"), findsNothing);

      await tester.tap(inContent(find.byKey(const Key("new_session_project"))));
      await tester.pumpAndSettle();
      expect(find.text("Open folder…"), findsOneWidget);
      await tester.tap(find.text("Project One").last);
      await tester.pumpAndSettle();

      expect(find.byType(NewSessionProjectPrompt), findsNothing);
      expect(tester.widget<NewSessionView>(inContent(find.byType(NewSessionView))).projectId, "p1");
    });

    testWidgets("collapse slides the sidebar out and the pane's restore button brings it back", (tester) async {
      final harness = await pumpShell(
        tester,
        size: const Size(1024, 800),
        initialLocation: "/sessions/p1/session-1?title=Session+One&readOnly=false",
        currentRouteDef: AppRouteDef.sessionDetail,
      );
      verifyPaneVisible(harness, isVisible: true, times: 1);
      expect(find.byKey(const Key("session-sidebar-restore")), findsNothing);

      await tester.tap(find.byKey(const Key("session-sidebar-collapse")));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      // Mid-motion the panel slides out at its full width while the pane widens.
      final midPane = tester.getSize(find.byKey(_content)).width;
      expect(midPane, greaterThan(1024 - _sidebarExtent));
      expect(midPane, lessThan(1024));
      expect(tester.getSize(find.byKey(_sidebar)).width, 320);
      expect(tester.getTopRight(find.byKey(_sidebar)).dx, 1024 - midPane - _margin);
      await tester.pumpAndSettle();

      expect(find.byKey(_sidebar), findsNothing);
      expect(tester.getSize(find.byKey(_content)).width, 1024);
      expect(inContent(find.byKey(_detail)), findsOneWidget);
      verifyPaneVisible(harness, isVisible: false, times: 1);

      await tester.tap(find.byKey(const Key("session-sidebar-restore")));
      await tester.pumpAndSettle();

      expect(find.byKey(_sidebar), findsOneWidget);
      expect(find.byKey(const Key("session-sidebar-restore")), findsNothing);
      expect(tester.getSize(find.byKey(_content)).width, 1024 - _sidebarExtent);
      verifyPaneVisible(harness, isVisible: true, times: 1);
    });

    testWidgets("the sidebar floats inside the safe area, and the pane keeps its pages clear of the side insets", (
      tester,
    ) async {
      // iPhone landscape: the notch side and the home indicator.
      const safeArea = EdgeInsets.fromLTRB(62, 0, 62, 21);
      tester.view.padding = FakeViewPadding(
        left: safeArea.left * tester.view.devicePixelRatio,
        right: safeArea.right * tester.view.devicePixelRatio,
        bottom: safeArea.bottom * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetPadding);
      await pumpShell(
        tester,
        size: const Size(874, 402),
        initialLocation: "/sessions/p1/session-1?title=Session+One&readOnly=false",
        currentRouteDef: AppRouteDef.sessionDetail,
      );

      expect(tester.widget(find.byKey(_sidebar)), isA<FloatingSidebarPanel>());
      expect(
        tester.getRect(find.byKey(_sidebar)),
        Rect.fromLTRB(
          safeArea.left + _margin,
          safeArea.top + _margin,
          safeArea.left + _margin + 320,
          402 - safeArea.bottom - _margin,
        ),
      );
      expect(tester.getTopLeft(find.byKey(_content)).dx, safeArea.left + _sidebarExtent);
      // The panel's rows and the pane beside it are clear of the notch's inset;
      // the pane's page also stops short of the far side's inset itself, as
      // pages lay their bodies out edge to edge.
      expect(
        MediaQuery.paddingOf(tester.element(inSidebar(find.byKey(const Key("home-new-session"))))),
        EdgeInsets.zero,
      );
      expect(
        tester.getRect(find.byKey(_detail)),
        Rect.fromLTRB(safeArea.left + _sidebarExtent, 0, 874 - safeArea.right, 402),
      );
      expect(MediaQuery.paddingOf(tester.element(find.byKey(_detail))), safeArea.copyWith(left: 0, right: 0));
      // A row's ink highlight is clipped with the list, not painted over the footer.
      final rowMaterial = find.ancestor(of: find.byKey(const Key("home-new-session")), matching: find.byType(Material));
      expect(
        tester.widgetList<Material>(rowMaterial).map((material) => material.clipBehavior),
        contains(Clip.hardEdge),
      );

      await tester.tap(find.byKey(const Key("session-sidebar-collapse")));
      await tester.pump();
      // The page glides left with the pane until it meets the notch's inset,
      // and never runs under it.
      var previousLeft = tester.getTopLeft(find.byKey(_detail)).dx;
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final left = tester.getTopLeft(find.byKey(_detail)).dx;
        expect(left, lessThanOrEqualTo(previousLeft));
        expect(left, greaterThanOrEqualTo(safeArea.left));
        previousLeft = left;
      }
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.byKey(_content)).dx, 0);
      expect(tester.getRect(find.byKey(_detail)), Rect.fromLTRB(safeArea.left, 0, 874 - safeArea.right, 402));
      expect(MediaQuery.paddingOf(tester.element(find.byKey(_detail))), safeArea.copyWith(left: 0, right: 0));

      // Restoring slides the page back with the pane, from the same inset.
      await tester.tap(find.byKey(const Key("session-sidebar-restore")));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getTopLeft(find.byKey(_detail)).dx, safeArea.left);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(_detail)).dx, safeArea.left + _sidebarExtent);
    });

    testWidgets("presents snackbars on the shell scaffold across the sidebar and the pane", (tester) async {
      await pumpShell(
        tester,
        size: const Size(1024, 800),
        initialLocation: "/sessions",
        currentRouteDef: AppRouteDef.home,
      );

      // Like the "session deleted" snackbar after a delete from the list.
      ScaffoldMessenger.of(tester.element(inSidebar(find.text("Session One")))).showSnackBar(
        const SnackBar(content: Text("Session deleted")),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.ancestor(of: find.byType(SnackBar), matching: find.byKey(const Key("session-sidebar-scaffold"))),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(SnackBar)).width, 1024);
    });

    testWidgets("rotating keeps the open session open and the same list cubit", (tester) async {
      final harness = await pumpShell(
        tester,
        size: const Size(1024, 768),
        initialLocation: "/sessions/p1/session-1?title=Session+One&readOnly=false",
        currentRouteDef: AppRouteDef.sessionDetail,
      );
      final before = BlocProvider.of<AllSessionsCubit>(tester.element(inSidebar(find.text("Session One"))));
      final detail = tester.element(find.byKey(_detail));

      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpAndSettle();

      expect(find.byKey(_sidebar), findsNothing);
      expect(find.byKey(_detail), findsOneWidget);
      expect(tester.element(find.byKey(_detail)), same(detail));
      // Full screen, the session leads back to the home.
      expect(find.byIcon(TablerRegular.chevron_left), findsOneWidget);
      verifyPaneVisible(harness, isVisible: false, times: 1);

      await tester.binding.setSurfaceSize(const Size(1024, 768));
      await tester.pumpAndSettle();

      expect(inContent(find.byKey(_detail)), findsOneWidget);
      expect(tester.element(find.byKey(_detail)), same(detail));
      expect(BlocProvider.of<AllSessionsCubit>(tester.element(inSidebar(find.text("Session One")))), same(before));
    });

    testWidgets("the open session's pane has one bar and no back button", (tester) async {
      await pumpShell(
        tester,
        size: const Size(1024, 800),
        initialLocation: "/sessions/p1/session-1?title=Session+One&readOnly=false",
        currentRouteDef: AppRouteDef.sessionDetail,
      );

      expect(inContent(find.byType(GlassAppBar)), findsOneWidget);
      expect(inContent(find.byType(BackButton)), findsNothing);
      expect(inContent(find.byIcon(TablerRegular.chevron_left)), findsNothing);
    });

    testWidgets("a page pushed in the pane has one bar with back and an inline title", (tester) async {
      await pumpShell(
        tester,
        size: const Size(1024, 800),
        initialLocation: "/sessions/p1/session-1/diffs",
        currentRouteDef: AppRouteDef.sessionDiffs,
        diffsBySession: {
          "session-1": [adaptiveTestDiff()],
        },
      );

      final bar = inContent(find.byType(GlassAppBar));
      expect(bar, findsOneWidget);
      expect(inContent(find.byIcon(TablerRegular.chevron_left)), findsOneWidget);
      expect(find.descendant(of: bar, matching: find.text("File changes")), findsOneWidget);
    });

    testWidgets("opening another session while a pushed new session is sending does not crash", (tester) async {
      // From an open session: the detail page swaps s1 -> s2 in place while the
      // pushed new-session page is the exiting route Flutter pops during build.
      final harness = await pumpShell(
        tester,
        size: const Size(1024, 800),
        initialLocation: "/sessions/p1/s1?title=Session+One&readOnly=false&name=Project+One",
        currentRouteDef: AppRouteDef.sessionDetail,
        sessions: [
          adaptiveTestSession(projectId: "p1", id: "s1", title: "Session One"),
          adaptiveTestSession(projectId: "p1", id: "s2", title: "Session Two"),
        ],
      );

      // Creation stays in flight: the user navigates away before it resolves.
      final createCompleter = Completer<ApiResponse<Session>>();
      addTearDown(() {
        if (!createCompleter.isCompleted) createCompleter.complete(ApiResponse.error(ApiError.generic()));
      });
      when(
        () => harness.sessionRepository.createSessionWithMessage(
          attachments: const [],
          projectId: any(named: "projectId"),
          pluginId: any(named: "pluginId"),
          text: any(named: "text"),
          agent: any(named: "agent"),
          model: any(named: "model"),
          variant: any(named: "variant"),
          fastMode: any(named: "fastMode"),
          command: any(named: "command"),
          dedicatedWorktree: any(named: "dedicatedWorktree"),
        ),
      ).thenAnswer((_) => createCompleter.future);
      final loc = AppLocalizations.of(tester.element(inSidebar(find.text("Session Two"))))!;

      // A new session pushed over the open one, as from a first project.
      unawaited(
        harness.router.push(const AppRoute.newSession(projectId: "p1", projectName: "Project One").buildPath()),
      );
      await tester.pumpAndSettle();
      final newSession = find.byType(NewSessionScreen);
      expect(newSession, findsOneWidget);

      // The fresh composer rests in its hold-to-talk pill; type instead.
      await tester.tap(find.descendant(of: newSession, matching: find.byIcon(TablerRegular.keyboard)));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: newSession, matching: find.byType(EditableText)), "do the thing");
      // Send only accepts taps once the composer has rebuilt around its text.
      await tester.pump();
      await tester.tap(find.descendant(of: newSession, matching: find.byIcon(TablerRegular.arrow_up)));
      await tester.pump();
      expect(find.byType(QueuedMessageBubble), findsOneWidget);

      // go_router pops the pushed page during the Navigator's build, so its
      // PopScope callback runs mid-build, where showing a snackbar throws.
      await tester.tap(inSidebar(find.text("Session Two")));
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byType(NewSessionScreen), findsNothing);
      expect(find.text(loc.newSessionLaunchingInBackground), findsOneWidget);
    });
  });
}
