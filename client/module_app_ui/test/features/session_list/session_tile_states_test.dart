import "package:flutter/gestures.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

/// A session row is a status slot, the title and when it last changed, over a
/// tertiary meta line: any state that needs words, then harness, branch and
/// pull request.
///
/// A working row twinkles on an infinite repeating animation, so these tests
/// pump fixed durations and never `pumpAndSettle` — it would pump to its
/// timeout and throw.
void main() {
  /// A 24px title and 20px meta line, 2px apart, inside 12px vertical padding.
  const rowHeight = 70.0;

  SessionTile tile({
    required Session session,
    bool isArchived = false,
    bool isRunning = false,
    bool unseen = false,
    bool selected = false,
    bool awaitingInput = false,
    bool isRetrying = false,
    int backgroundTaskCount = 0,
    bool canOpen = true,
    VoidCallback? onArchive,
    VoidCallback? onToggleUnread,
  }) {
    return SessionTile(
      session: session,
      isArchived: isArchived,
      isRunning: isRunning,
      unseen: unseen,
      selected: selected,
      awaitingInput: awaitingInput,
      isRetrying: isRetrying,
      backgroundTaskCount: backgroundTaskCount,
      onTap: canOpen ? () {} : null,
      menuEntries: () => const [],
      onArchive: onArchive ?? () {},
      onDelete: () {},
      onToggleUnread: onToggleUnread ?? () {},
    );
  }

  Future<void> pumpTile(WidgetTester tester, SessionTile row, {Widget Function(Widget child)? wrap}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Material(child: Column(children: [if (wrap == null) row else wrap(row)])),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> pumpPointerTile(WidgetTester tester, SessionTile row) => pumpTile(
    tester,
    row,
    wrap: (child) => PregoInteractionScope(mode: PregoInteractionMode.pointer, child: child),
  );

  FontWeight? titleWeight(WidgetTester tester, String title) => tester.widget<Text>(find.text(title)).style!.fontWeight;

  /// Whether the row's sparkle is twinkling. `tester.hasRunningAnimations` is
  /// avoided for symmetry with the project list's states test: the sparkle's
  /// contract is read off the widget, and that the flag really does start and
  /// stop the loop is PregoAiLoader's own test.
  bool sparkleTwinkles(WidgetTester tester) => tester.widget<PregoAiLoader>(find.byType(PregoAiLoader)).animate;

  final colors = PregoDesignSystem.light.colors;
  final now = DateTime.now().millisecondsSinceEpoch;

  // Every state on both apps: the slot leads the title, and the time stays.
  for (final pointer in [false, true]) {
    group(pointer ? "pointer rows" : "touch rows", () {
      Future<void> pump(WidgetTester tester, SessionTile row) =>
          pointer ? pumpPointerTile(tester, row) : pumpTile(tester, row);

      testWidgets("a running session leads with a twinkling sparkle and keeps its time", (tester) async {
        await pump(
          tester,
          tile(
            session: testSession(title: "My Session", updatedAt: now),
            isRunning: true,
          ),
        );

        expect(sparkleTwinkles(tester), isTrue);
        expect(tester.getSize(find.byType(PregoAiLoader)), const Size.square(16));
        expect(
          tester.getCenter(find.byType(PregoAiLoader)).dx,
          lessThan(tester.getTopLeft(find.text("My Session")).dx),
        );
        // A plain live turn carries no words — the twinkle is the signal.
        expect(find.text("Running"), findsNothing);
        expect(find.text("now"), findsOneWidget);
      });

      testWidgets("an unread session rests on the sparkle and weights its title", (tester) async {
        await pump(
          tester,
          tile(
            session: testSession(title: "My Session", updatedAt: now),
            unseen: true,
          ),
        );

        expect(sparkleTwinkles(tester), isFalse);
        expect(titleWeight(tester, "My Session"), FontWeight.w500);
        expect(find.text("now"), findsOneWidget);
      });

      testWidgets("a waiting session shows an amber dot and says Waiting in amber", (tester) async {
        await pump(
          tester,
          tile(
            session: testSession(title: "My Session", updatedAt: now),
            awaitingInput: true,
          ),
        );

        expect(find.byType(PregoAiLoader), findsNothing);
        final dot = tester.widget<Container>(
          find.descendant(
            of: find.byType(SessionTile),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Container &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
            ),
          ),
        );
        expect((dot.decoration! as BoxDecoration).color, colors.fgWarningPrimary);
        expect(tester.widget<Text>(find.text("Waiting")).style?.color, colors.textWarningPrimary);
        expect(find.text("now"), findsOneWidget);
      });

      testWidgets("waiting wins over a turn still counted as running", (tester) async {
        await pump(
          tester,
          tile(session: testSession(title: "My Session"), isRunning: true, awaitingInput: true, isRetrying: true),
        );

        expect(find.byType(PregoAiLoader), findsNothing);
        expect(find.text("Waiting"), findsOneWidget);
      });

      testWidgets("an idle, read session leaves the slot empty and titles still line up", (tester) async {
        await pump(
          tester,
          tile(
            session: testSession(id: "a", title: "Idle", updatedAt: now),
          ),
        );
        final idleTitle = tester.getTopLeft(find.text("Idle")).dx;
        await pump(
          tester,
          tile(
            session: testSession(id: "b", title: "Busy", updatedAt: now),
            isRunning: true,
          ),
        );

        expect(tester.getTopLeft(find.text("Busy")).dx, idleTitle);
        expect(titleWeight(tester, "Busy"), FontWeight.w400);
      });

      testWidgets("a long branch shortens in the middle in the tertiary meta line", (tester) async {
        const branch = "sesori/a-very-long-worktree-branch-name-that-cannot-possibly-fit-on-one-row-end";
        await pump(
          tester,
          tile(
            session: testSession(title: "My Session", branchName: branch, pluginId: "claude", updatedAt: now),
          ),
        );

        expect(tester.widget<Text>(find.text("Claude Code")).style?.color, colors.textTertiary);
        final shown = tester.renderObject<RenderEllipsisText>(find.byType(PregoEllipsisText)).shownText;
        expect(shown, startsWith("sesori/"));
        expect(shown, endsWith("end"));
        expect(shown, contains("…"));
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets("the time is secondary, outranking the tertiary meta line", (tester) async {
    await pumpTile(
      tester,
      tile(
        session: testSession(title: "My Session", updatedAt: now),
      ),
    );

    expect(tester.widget<Text>(find.text("now")).style?.color, colors.textSecondary);
    expect(tester.getSize(find.byType(SessionTile)).height, rowHeight);
  });

  testWidgets("every row names its harness, including one this app doesn't know", (tester) async {
    await pumpTile(
      tester,
      tile(
        session: testSession(title: "My Session", pluginId: "opencode"),
      ),
    );
    expect(find.text("OpenCode"), findsOneWidget);

    await pumpTile(
      tester,
      tile(
        session: testSession(title: "My Session", pluginId: "harness-from-the-future"),
      ),
    );
    expect(find.text("harness-from-the-future"), findsOneWidget);
  });

  testWidgets("retrying and background tasks lead the meta line in their colours", (tester) async {
    await pumpTile(tester, tile(session: testSession(title: "My Session"), isRunning: true, isRetrying: true));
    expect(tester.widget<Text>(find.text("Running (retrying)")).style?.color, colors.fgErrorPrimary);

    await pumpTile(tester, tile(session: testSession(title: "My Session"), isRunning: true, backgroundTaskCount: 2));
    expect(find.text("2 background tasks"), findsOneWidget);
  });

  testWidgets("assistive technology hears the state before the title, then the time", (tester) async {
    final semantics = tester.ensureSemantics();

    await pumpTile(
      tester,
      tile(
        session: testSession(title: "My Session", updatedAt: now),
        isRunning: true,
      ),
    );
    expect(find.bySemanticsLabel(RegExp("^Running\nMy Session\njust now")), findsOneWidget);

    await pumpTile(
      tester,
      tile(
        session: testSession(title: "My Session", updatedAt: now),
        unseen: true,
      ),
    );
    expect(find.bySemanticsLabel(RegExp("^New activity\nMy Session")), findsOneWidget);

    await pumpTile(
      tester,
      tile(
        session: testSession(title: "My Session", updatedAt: now),
        awaitingInput: true,
      ),
    );
    expect(find.bySemanticsLabel(RegExp("^Awaiting input\nMy Session")), findsOneWidget);
    // The slot speaks the state, so the meta line's "Waiting" stays silent.
    expect(find.bySemanticsLabel(RegExp("Waiting")), findsNothing);

    semantics.dispose();
  });

  testWidgets("the pull request shares the meta line with the branch", (tester) async {
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

    expect(find.text("sesori/add-search"), findsOneWidget);
    expect(find.text("PR #42"), findsOneWidget);
    expect(tester.getSize(find.byType(SessionTile)).height, rowHeight);
  });

  testWidgets("a long branch leaves the pull request its full width", (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = testSession(title: "My Session", branchName: "visual-hierarchy/a-very-long-phone-activity")
        .copyWith(
          pullRequest: const PullRequestInfo(
            number: 1631,
            url: "https://github.com/sesori-ai/sesori_apps_monorepo/pull/1631",
            title: "Show Activity",
            state: PrState.open,
            mergeableStatus: PrMergeableStatus.mergeable,
            reviewDecision: PrReviewDecision.reviewRequired,
            checkStatus: PrCheckStatus.pending,
          ),
        );

    await pumpTile(tester, tile(session: session));

    // The status row clips only when squeezed below its own width.
    final row = find.byType(PrStatusRow);
    final content = find.descendant(of: row, matching: find.byType(Row)).first;
    expect(tester.getSize(row).width, greaterThanOrEqualTo(tester.getSize(content).width));
  });

  testWidgets("a full meta line fits the narrow landscape split pane", (tester) async {
    tester.view.physicalSize = const Size(258, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = testSession(title: "My Session", branchName: "sesori/a-very-long-worktree-branch", updatedAt: now)
        .copyWith(
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

    await pumpTile(tester, tile(session: session, awaitingInput: true));

    expect(tester.takeException(), isNull);
  });

  testWidgets("the meta line survives scaled-up accessibility text without overflowing", (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 3.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = testSession(title: "My Session", branchName: "sesori/a-very-long-worktree-branch", updatedAt: now)
        .copyWith(
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

    await pumpTile(tester, tile(session: session, awaitingInput: true));

    expect(tester.takeException(), isNull);
  });

  testWidgets("a title too long for its line fades out instead of ellipsizing", (tester) async {
    await pumpTile(
      tester,
      tile(session: testSession(title: "A session title far too long to fit the width of a phone's list row")),
    );

    // The fade replaces the ellipsis: the glyphs run toward the trailing slot
    // and dissolve there rather than stopping on a hard "…". The paragraph
    // fades itself, so a row that has nothing to fade pays nothing for it.
    final title = tester.widget<Text>(find.textContaining("A session title"));
    expect(title.overflow, TextOverflow.fade);
    expect(title.maxLines, 1);
    expect(find.byType(ShaderMask), findsNothing);
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

    testWidgets("does not announce a dead button when the shell has no detail route", (tester) async {
      final semantics = tester.ensureSemantics();

      await pumpTile(
        tester,
        tile(
          session: testSession(
            title: "My Session",
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
          canOpen: false,
        ),
      );

      expect(
        tester.getSemantics(find.descendant(of: find.byType(SessionTile), matching: find.byType(MergeSemantics))),
        matchesSemantics(
          label: "My Session\njust now\nplugin-1",
          isButton: false,
          hasTapAction: false,
          hasLongPressAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );

      semantics.dispose();
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
          label: "My Session\njust now\nplugin-1\nsesori/add-search",
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

  group("in pointer mode", () {
    testWidgets("an idle row stays near 44 pt with its meta line", (tester) async {
      await pumpPointerTile(
        tester,
        tile(
          session: testSession(title: "My Session", updatedAt: now),
        ),
      );

      expect(tester.getSize(find.byType(SessionTile)).height, inInclusiveRange(44, 48));
      expect(find.text("now"), findsOneWidget);
    });

    testWidgets("hovering swaps the time for the read toggle and Archive, which call the row's handlers", (
      tester,
    ) async {
      var archived = 0;
      var toggled = 0;
      final session = testSession(title: "My Session", updatedAt: now);
      await pumpPointerTile(
        tester,
        tile(session: session, onArchive: () => archived++, onToggleUnread: () => toggled++),
      );
      const archive = Key("session-tile-hover-archive");
      const toggle = Key("session-tile-hover-toggle-unread");
      expect(find.byKey(archive), findsNothing);
      final restingHeight = tester.getSize(find.byType(SessionTile)).height;

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text("My Session")));
      await tester.pump();
      expect(tester.getSize(find.byType(SessionTile)).height, restingHeight);

      await tester.tap(find.byKey(archive));
      await tester.tap(find.byKey(toggle));
      expect((archived, toggled), (1, 1));
    });

    testWidgets("keyboard focus reveals them too, and an archived row offers no Archive", (tester) async {
      await pumpPointerTile(tester, tile(session: testSession(title: "My Session"), isArchived: true));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(find.byKey(const Key("session-tile-hover-toggle-unread")), findsOneWidget);
      expect(find.byKey(const Key("session-tile-hover-archive")), findsNothing);
    });
  });

  group("scheduled auto-continuation", () {
    final continueAt = DateTime.now().add(const Duration(minutes: 1)).millisecondsSinceEpoch;
    Session scheduled({bool enabled = true, AutoContinuationAvailability availability = .conditional}) =>
        testSession(title: "My Session", updatedAt: now).copyWith(
          autoContinuation: SessionAutoContinuationView(
            enabled: enabled,
            availability: availability,
            status: SessionAutoContinuationStatus.resetKnown(resetAt: continueAt, continueAt: continueAt),
          ),
        );

    testWidgets("a quiet row shows when it resumes in place of its time", (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTile(tester, tile(session: scheduled()));

      expect(find.byIcon(TablerRegular.clock), findsOneWidget);
      expect(find.textContaining("Resumes "), findsOneWidget);
      expect(find.text("now"), findsNothing);
      expect(find.bySemanticsLabel(RegExp("Resumes at ")), findsOneWidget);
      semantics.dispose();
    });

    for (final (name, running, awaiting) in [("running", true, false), ("waiting", false, true)]) {
      testWidgets("a $name row keeps its time", (tester) async {
        await pumpTile(tester, tile(session: scheduled(), isRunning: running, awaitingInput: awaiting));

        expect(find.textContaining("Resumes"), findsNothing);
        expect(find.text("now"), findsOneWidget);
      });
    }

    testWidgets("a disabled, unavailable or unknown preference and an older bridge keep the time", (tester) async {
      for (final session in [
        scheduled(enabled: false),
        scheduled(availability: .unavailable),
        scheduled(availability: .unknown),
        testSession(title: "My Session", updatedAt: now),
      ]) {
        await pumpTile(tester, tile(session: session));

        expect(find.textContaining("Resumes"), findsNothing);
        expect(find.text("now"), findsOneWidget);
      }
    });
  });
}
