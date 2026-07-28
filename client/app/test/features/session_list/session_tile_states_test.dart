import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/core/status_colors.dart";
import "package:sesori_mobile/features/session_list/session_tile.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

/// A session row is a title line led by its harness logo and ended by either
/// the state sparkle or when the session last changed, over an indented
/// footer: branch, pull request and any state that needs words.
///
/// A working row twinkles on an infinite repeating animation, so these tests
/// pump fixed durations and never `pumpAndSettle` — it would pump to its
/// timeout and throw.
void main() {
  /// The row is laid out from the type scale it renders — a 16/24 title over a
  /// 14/20 footer line, inside 12px of padding — and the whole list is pitched
  /// on it. A style change that drifts this drifts the list.
  const rowHeight = 70.0;

  SessionTile tile({
    required Session session,
    bool isActive = false,
    bool unseen = false,
    bool selected = false,
    bool awaitingInput = false,
    bool isRetrying = false,
    int backgroundTaskCount = 0,
  }) {
    return SessionTile(
      session: session,
      isArchived: false,
      isActive: isActive,
      unseen: unseen,
      selected: selected,
      awaitingInput: awaitingInput,
      isRetrying: isRetrying,
      backgroundTaskCount: backgroundTaskCount,
      onTap: () {},
      menuEntries: () => const [],
      onArchive: () {},
      onDelete: () {},
      onToggleUnread: () {},
    );
  }

  Future<void> pumpTile(WidgetTester tester, SessionTile row) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Material(child: Column(children: [row])),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  FontWeight? titleWeight(WidgetTester tester, String title) => tester.widget<Text>(find.text(title)).style!.fontWeight;

  /// Whether the row's sparkle is twinkling. `tester.hasRunningAnimations` is
  /// avoided for symmetry with the project list's states test: the sparkle's
  /// contract is read off the widget, and that the flag really does start and
  /// stop the loop is PregoAiLoader's own test.
  bool sparkleTwinkles(WidgetTester tester) => tester.widget<PregoAiLoader>(find.byType(PregoAiLoader)).animate;

  group("a session an agent is working in", () {
    testWidgets("marks itself with a twinkling sparkle and no label", (tester) async {
      await pumpTile(tester, tile(session: testSession(title: "My Session"), isActive: true));

      expect(find.byType(PregoAiLoader), findsOneWidget);
      expect(sparkleTwinkles(tester), isTrue);
      // A plain live turn carries no words — the twinkle is the signal.
      expect(find.text("Running"), findsNothing);
      expect(titleWeight(tester, "My Session"), FontWeight.w400);
    });

    testWidgets("still tells assistive technology it is running", (tester) async {
      final semantics = tester.ensureSemantics();

      await pumpTile(tester, tile(session: testSession(title: "My Session"), isActive: true));
      // The twinkle is visual-only, so the row's merged semantics must carry
      // the words the old "Running" label used to speak.
      expect(find.bySemanticsLabel(RegExp("Running")), findsOneWidget);

      await pumpTile(tester, tile(session: testSession(title: "My Session")));
      expect(find.bySemanticsLabel(RegExp("Running")), findsNothing);

      semantics.dispose();
    });

    testWidgets("keeps its words when input is wanted", (tester) async {
      await pumpTile(
        tester,
        tile(session: testSession(title: "My Session"), isActive: true, awaitingInput: true),
      );

      final label = tester.widget<Text>(find.text("Awaiting input"));
      expect(label.style?.color, kStatusAmber);
    });

    testWidgets("keeps its words when retrying", (tester) async {
      await pumpTile(
        tester,
        tile(session: testSession(title: "My Session"), isActive: true, isRetrying: true),
      );

      final label = tester.widget<Text>(find.text("Running (retrying)"));
      expect(label.style?.color, PregoDesignSystem.light.colors.fgErrorPrimary);
    });

    testWidgets("counts the tasks running behind the turn", (tester) async {
      await pumpTile(
        tester,
        tile(session: testSession(title: "My Session"), isActive: true, backgroundTaskCount: 2),
      );

      expect(find.text("2 background tasks"), findsOneWidget);
    });
  });

  group("a session with activity the user hasn't opened", () {
    testWidgets("rests on the solid sparkle and weights its title", (tester) async {
      await pumpTile(tester, tile(session: testSession(title: "My Session"), unseen: true));

      expect(find.byType(PregoAiLoader), findsOneWidget);
      // Unopened activity is a state, not an event: the sparkle marks it but
      // must not animate, or a list nobody is working in would twinkle forever.
      expect(sparkleTwinkles(tester), isFalse);
      expect(titleWeight(tester, "My Session"), FontWeight.w500);
    });

    testWidgets("still tells assistive technology about the unopened activity", (tester) async {
      final semantics = tester.ensureSemantics();

      await pumpTile(tester, tile(session: testSession(title: "My Session"), unseen: true));
      // The resting sparkle is visual-only, so the row's merged semantics must
      // carry the unread meaning title weight alone does not announce.
      expect(find.bySemanticsLabel(RegExp("New activity")), findsOneWidget);

      await pumpTile(tester, tile(session: testSession(title: "My Session")));
      expect(find.bySemanticsLabel(RegExp("New activity")), findsNothing);

      semantics.dispose();
    });

    testWidgets("cedes the sparkle to a live turn but keeps the weight", (tester) async {
      await pumpTile(tester, tile(session: testSession(title: "My Session"), isActive: true, unseen: true));

      expect(sparkleTwinkles(tester), isTrue);
      expect(titleWeight(tester, "My Session"), FontWeight.w500);
    });
  });

  testWidgets("a read, idle session shows no sparkle and tells the time instead", (tester) async {
    final session = testSession(
      title: "My Session",
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await pumpTile(tester, tile(session: session));

    expect(find.byType(PregoAiLoader), findsNothing);
    expect(titleWeight(tester, "My Session"), FontWeight.w400);
    // The trailing slot is a few characters wide, so the time drops its
    // phrasing rather than wrapping.
    expect(find.text("now"), findsOneWidget);
  });

  group("the harness leading the title", () {
    testWidgets("marks the row with the backend driving the session", (tester) async {
      await pumpTile(tester, tile(session: testSession(title: "My Session", pluginId: "opencode")));
      expect(find.byIcon(VESPRSolid.opencode), findsOneWidget);

      await pumpTile(tester, tile(session: testSession(title: "My Session", pluginId: "codex")));
      expect(find.byIcon(VESPRSolid.codex), findsOneWidget);
    });

    testWidgets("falls back to a plug for a harness this app doesn't know", (tester) async {
      // A newer bridge can advertise harnesses this build has never heard of;
      // the slot still has to hold something.
      await pumpTile(tester, tile(session: testSession(title: "My Session", pluginId: "harness-from-the-future")));

      expect(find.byIcon(TablerRegular.plug), findsOneWidget);
    });

    testWidgets("names the harness for assistive technology", (tester) async {
      final semantics = tester.ensureSemantics();

      // The logo is the row's only backend cue, so two otherwise-identical
      // sessions have to be told apart by ear as well as by eye.
      await pumpTile(tester, tile(session: testSession(title: "My Session", pluginId: "opencode")));
      expect(find.bySemanticsLabel(RegExp("OpenCode session")), findsOneWidget);

      await pumpTile(tester, tile(session: testSession(title: "My Session", pluginId: "harness-from-the-future")));
      expect(find.bySemanticsLabel(RegExp("harness-from-the-future session")), findsOneWidget);

      semantics.dispose();
    });
  });

  group("the trailing slot", () {
    testWidgets("gives the time up to the sparkle while the session has one", (tester) async {
      final session = testSession(title: "My Session", updatedAt: DateTime.now().millisecondsSinceEpoch);

      await pumpTile(tester, tile(session: session, isActive: true));
      expect(find.text("now"), findsNothing);

      await pumpTile(tester, tile(session: session, unseen: true));
      expect(find.text("now"), findsNothing);
    });

    testWidgets("keeps a session older than the relative window to one narrow line", (tester) async {
      // Past 30 days the slot shows a date, and some locales write those with
      // spaces; it holds one line so a stale session can't reshape the row.
      await pumpTile(tester, tile(session: testSession(title: "My Session", updatedAt: 1700000000000)));

      final stamp = tester.widget<Text>(find.textContaining("2023"));
      expect(stamp.maxLines, 1);
      expect(stamp.softWrap, isFalse);
    });

    testWidgets("spells the year of a session from an earlier one", (tester) async {
      final lastYear = DateTime(DateTime.now().year - 1, 6, 15);

      await pumpTile(
        tester,
        tile(session: testSession(title: "My Session", updatedAt: lastYear.millisecondsSinceEpoch)),
      );

      expect(find.textContaining("${lastYear.year}"), findsOneWidget);
    });

    testWidgets("leaves the year off a session from this one", (tester) async {
      // The year only earns the slot's width when leaving it out would be
      // ambiguous. (In the first weeks of January this date is still inside
      // the relative window, which spells no year either.)
      final thisYear = DateTime(DateTime.now().year);

      await pumpTile(
        tester,
        tile(session: testSession(title: "My Session", updatedAt: thisYear.millisecondsSinceEpoch)),
      );

      expect(find.textContaining("${thisYear.year}"), findsNothing);
    });

    testWidgets("still speaks the time the sparkle took the space from, after the state", (tester) async {
      final semantics = tester.ensureSemantics();
      final session = testSession(title: "My Session", updatedAt: DateTime.now().millisecondsSinceEpoch);

      await pumpTile(tester, tile(session: session, isActive: true));
      // Nothing on screen says when this session last changed, so the row's
      // spoken label has to — in full, not as the "now" glance mark, and after
      // the state that took the slot from it.
      expect(find.bySemanticsLabel(RegExp("Running\njust now")), findsOneWidget);

      semantics.dispose();
    });
  });

  group("the footer's details", () {
    testWidgets("show the workspace branch when the bridge knows one", (tester) async {
      final session = testSession(title: "My Session", branchName: "sesori/add-search");

      await pumpTile(tester, tile(session: session));

      expect(find.byIcon(TablerRegular.git_branch), findsOneWidget);
      expect(find.text("sesori/add-search"), findsOneWidget);
    });

    testWidgets("hold no branch slot for a session without one", (tester) async {
      await pumpTile(tester, tile(session: testSession(title: "My Session")));

      expect(find.byIcon(TablerRegular.git_branch), findsNothing);
    });

    testWidgets("surface the pull request beside the branch", (tester) async {
      final session = testSession(title: "My Session", branchName: "sesori/add-search").copyWith(
        pullRequest: const PullRequestInfo(
          number: 42,
          url: "https://github.com/sesori-ai/sesori_apps_monorepo/pull/42",
          title: "Add project search",
          state: PrState.open,
          mergeableStatus: PrMergeableStatus.mergeable,
          reviewDecision: PrReviewDecision.unknown,
          checkStatus: PrCheckStatus.none,
        ),
      );

      await pumpTile(tester, tile(session: session));

      expect(find.text("PR #42"), findsOneWidget);
      expect(find.text("Open"), findsOneWidget);
    });

    testWidgets("share the line without overflowing under scaled-up accessibility text", (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final session =
          testSession(
            title: "My Session",
            branchName: "sesori/a-very-long-worktree-branch",
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ).copyWith(
            pullRequest: const PullRequestInfo(
              number: 483,
              url: "https://github.com/sesori-ai/sesori_apps_monorepo/pull/483",
              title: "Redesign the session list item",
              state: PrState.open,
              mergeableStatus: PrMergeableStatus.conflicting,
              reviewDecision: PrReviewDecision.changesRequested,
              checkStatus: PrCheckStatus.failure,
            ),
          );

      // Three details on one line at 3x is the worst case the footer has to
      // survive; each of them yields rather than the row overflowing.
      await pumpTile(tester, tile(session: session, isActive: true, awaitingInput: true));

      expect(tester.takeException(), isNull);
    });
  });

  group("a title too long for its line", () {
    testWidgets("fades out instead of ellipsizing", (tester) async {
      await pumpTile(
        tester,
        tile(session: testSession(title: "A session title far too long to fit the width of a phone's list row")),
      );

      final title = tester.widget<Text>(find.textContaining("A session title"));
      // The fade replaces the ellipsis: the glyphs run under the trailing slot
      // and dissolve there rather than stopping on a hard "…".
      expect(title.overflow, TextOverflow.clip);
      expect(
        find.ancestor(of: find.byWidget(title), matching: find.byType(ShaderMask)),
        findsOneWidget,
      );
    });

    testWidgets("costs a title that fits nothing", (tester) async {
      await pumpTile(tester, tile(session: testSession(title: "Short")));

      // A mask is an offscreen pass per row that wears it, so rows with
      // nothing to fade must not be wrapped in one.
      expect(find.byType(ShaderMask), findsNothing);
    });
  });

  group("row chrome", () {
    testWidgets("tints itself when selected in the split view", (tester) async {
      await pumpTile(tester, tile(session: testSession(title: "My Session"), selected: true));

      final ink = tester.widget<Ink>(
        find.descendant(of: find.byType(SessionTile), matching: find.byType(Ink)),
      );
      final colors = PregoDesignSystem.light.colors;
      expect((ink.decoration as BoxDecoration?)?.color, colors.bgBrandSolid.withValues(alpha: 0.08));
    });

    testWidgets("stays untinted when not selected", (tester) async {
      await pumpTile(tester, tile(session: testSession(title: "My Session")));

      final ink = tester.widget<Ink>(
        find.descendant(of: find.byType(SessionTile), matching: find.byType(Ink)),
      );
      expect(ink.decoration, isNull);
    });

    testWidgets("keeps the list's pitch with or without anything to say", (tester) async {
      await pumpTile(tester, tile(session: testSession(title: "Full").copyWith(time: null)));
      expect(tester.getSize(find.byType(SessionTile)).height, rowHeight);

      await pumpTile(
        tester,
        tile(
          session: testSession(
            title: "Quiet",
            branchName: "main",
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
          isActive: true,
        ),
      );
      expect(tester.getSize(find.byType(SessionTile)).height, rowHeight);
    });

    testWidgets("announces the whole row as one button", (tester) async {
      final semantics = tester.ensureSemantics();
      final session = testSession(
        title: "My Session",
        branchName: "sesori/add-search",
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await pumpTile(tester, tile(session: session));

      expect(
        tester.getSemantics(find.descendant(of: find.byType(SessionTile), matching: find.byType(MergeSemantics))),
        matchesSemantics(
          label: "plugin-1 session\nMy Session\njust now\nsesori/add-search",
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasLongPressAction: true,
          hasFocusAction: true,
        ),
      );

      semantics.dispose();
    });
  });
}
