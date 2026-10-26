import "package:flutter/gestures.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

/// A session row is the harness logo, the title with its status mark after it
/// and when it last changed, over a tertiary meta line: any state that needs
/// words, then the project.
///
/// A working row twinkles on an infinite repeating animation, so these tests
/// pump fixed durations and never `pumpAndSettle` — it would pump to its
/// timeout and throw.
void main() {
  /// A 24px title and 20px meta line, 2px apart, inside 12px vertical padding.
  const rowHeight = 70.0;

  SessionTile tile({
    required Session session,
    String? projectLabel,
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
      projectLabel: projectLabel,
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

  // Every state on both apps: the mark follows the title, and the time stays.
  for (final pointer in [false, true]) {
    group(pointer ? "pointer rows" : "touch rows", () {
      Future<void> pump(WidgetTester tester, SessionTile row) =>
          pointer ? pumpPointerTile(tester, row) : pumpTile(tester, row);

      testWidgets("a running session ends its title with a twinkling sparkle and keeps its time", (tester) async {
        await pump(
          tester,
          tile(
            session: testSession(title: "My Session", updatedAt: now),
            isRunning: true,
          ),
        );

        expect(sparkleTwinkles(tester), isTrue);
        final sparkle = find.byType(PregoAiLoader);
        expect(tester.getSize(sparkle), const Size.square(16));
        // Right beside a short title, well ahead of the time.
        expect(tester.getTopLeft(sparkle).dx - tester.getTopRight(find.text("My Session")).dx, 4);
        expect(tester.getTopRight(sparkle).dx, lessThan(tester.getTopLeft(find.text("now")).dx));
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

      testWidgets("an idle, read session shows no mark and its title starts where a busy one does", (tester) async {
        await pump(
          tester,
          tile(
            session: testSession(id: "a", title: "Idle", updatedAt: now),
          ),
        );
        expect(find.byType(PregoAiLoader), findsNothing);
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

      testWidgets("the logo leads 12 px in, with the tertiary meta line under it and no branch", (tester) async {
        await pump(
          tester,
          tile(
            session: testSession(title: "My Session", branchName: "sesori/add-search", updatedAt: now),
            projectLabel: "demo-app",
          ),
        );

        expect(tester.getTopLeft(find.byType(PregoBrandLogo)).dx, 12);
        expect(tester.getTopLeft(find.text("demo-app")).dx, 12);
        expect(tester.widget<Text>(find.text("demo-app")).style?.color, colors.textTertiary);
        // The time keeps 16 px from the trailing edge.
        expect(tester.getTopRight(find.text("now")).dx, 800 - 16);
        expect(find.text("sesori/add-search"), findsNothing);
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

  testWidgets("the harness logo leads the title and speaks the harness, including one this app doesn't know", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await pumpTile(
      tester,
      tile(
        session: testSession(title: "My Session", pluginId: "opencode", updatedAt: now),
        isRunning: true,
      ),
    );
    final logo = find.byType(PregoBrandLogo);
    expect(tester.widget<PregoBrandLogo>(logo).pluginId, "opencode");
    expect(tester.getSize(logo), const Size.square(16));
    // Leading the row, ahead of the title and its mark.
    expect(tester.getTopRight(logo).dx, lessThan(tester.getTopLeft(find.text("My Session")).dx));
    expect(find.bySemanticsLabel(RegExp("^OpenCode\nMy Session\nRunning\njust now")), findsOneWidget);
    // The logo names the harness, so the meta line no longer does.
    expect(find.text("OpenCode"), findsNothing);
    final knownTitle = tester.getTopLeft(find.text("My Session")).dx;

    await pumpTile(
      tester,
      tile(
        session: testSession(title: "My Session", pluginId: "harness-from-the-future"),
      ),
    );
    expect(find.bySemanticsLabel(RegExp("^harness-from-the-future\nMy Session")), findsOneWidget);
    expect(tester.getTopLeft(find.text("My Session")).dx, knownTitle, reason: "titles line up across harnesses");

    semantics.dispose();
  });

  testWidgets("a project label leads the meta line, and a missing one leaves the row as tall", (tester) async {
    await pumpTile(
      tester,
      tile(
        session: testSession(title: "My Session", updatedAt: now),
        projectLabel: "demo-app",
      ),
    );
    expect(find.text("demo-app"), findsOneWidget);
    expect(tester.getSize(find.byType(SessionTile)).height, rowHeight);

    // Nothing at all for the meta line: it still holds its height, so a row
    // never jumps when a project or a state label arrives.
    await pumpTile(
      tester,
      tile(
        session: testSession(title: "My Session", updatedAt: now),
      ),
    );
    expect(tester.getSize(find.byType(SessionTile)).height, rowHeight);
  });

  testWidgets("retrying and background tasks lead the meta line in their colours", (tester) async {
    await pumpTile(tester, tile(session: testSession(title: "My Session"), isRunning: true, isRetrying: true));
    expect(tester.widget<Text>(find.text("Running (retrying)")).style?.color, colors.fgErrorPrimary);

    await pumpTile(tester, tile(session: testSession(title: "My Session"), isRunning: true, backgroundTaskCount: 2));
    expect(find.text("2 background tasks"), findsOneWidget);
  });

  testWidgets("assistive technology hears the harness, the title, then the state and the time", (tester) async {
    final semantics = tester.ensureSemantics();

    await pumpTile(
      tester,
      tile(
        session: testSession(title: "My Session", updatedAt: now),
        isRunning: true,
      ),
    );
    expect(find.bySemanticsLabel(RegExp("^plugin-1\nMy Session\nRunning\njust now")), findsOneWidget);

    await pumpTile(
      tester,
      tile(
        session: testSession(title: "My Session", updatedAt: now),
        unseen: true,
      ),
    );
    expect(find.bySemanticsLabel(RegExp("^plugin-1\nMy Session\nNew activity")), findsOneWidget);

    await pumpTile(
      tester,
      tile(
        session: testSession(title: "My Session", updatedAt: now),
        awaitingInput: true,
      ),
    );
    expect(find.bySemanticsLabel(RegExp("^plugin-1\nMy Session\nAwaiting input")), findsOneWidget);
    // The mark speaks the state, so the meta line's "Waiting" stays silent.
    expect(find.bySemanticsLabel(RegExp("Waiting")), findsNothing);

    semantics.dispose();
  });

  testWidgets("a state label and the project follow each other across a middle dot", (tester) async {
    await pumpTile(
      tester,
      tile(
        session: testSession(title: "My Session"),
        projectLabel: "demo-app",
        awaitingInput: true,
      ),
    );

    expect(tester.getTopRight(find.text("Waiting")).dx, lessThan(tester.getTopLeft(find.text("demo-app")).dx));
    expect(find.text(" · "), findsOneWidget);
    expect(tester.getSize(find.byType(SessionTile)).height, rowHeight);
  });

  testWidgets("a full meta line fits the narrow landscape split pane", (tester) async {
    tester.view.physicalSize = const Size(258, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = testSession(title: "My Session", updatedAt: now);

    await pumpTile(tester, tile(session: session, projectLabel: "a-very-long-project-name", awaitingInput: true));

    expect(tester.takeException(), isNull);
  });

  testWidgets("the meta line survives scaled-up accessibility text without overflowing", (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 3.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = testSession(title: "My Session", updatedAt: now);

    await pumpTile(tester, tile(session: session, projectLabel: "demo-app", awaitingInput: true));

    expect(tester.takeException(), isNull);
  });

  testWidgets("a title too long for its line fades out before its mark, which stays ahead of the time", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpTile(
      tester,
      tile(
        session: testSession(
          title: "A session title far too long to fit the width of a phone's list row",
          pluginId: "claude",
          updatedAt: now,
        ),
        isRunning: true,
      ),
    );

    // Between the logo and the mark; the mark and the time keep their place.
    expect(tester.takeException(), isNull);
    final titleBox = find.textContaining("A session title");
    final sparkle = find.byType(PregoAiLoader);
    expect(tester.getTopLeft(titleBox).dx, greaterThan(tester.getTopRight(find.byType(PregoBrandLogo)).dx));
    expect(tester.getTopRight(titleBox).dx, lessThan(tester.getTopLeft(sparkle).dx));
    expect(tester.getTopRight(sparkle).dx, lessThan(tester.getTopLeft(find.text("now")).dx));

    // The fade replaces the ellipsis: the glyphs run toward the mark
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
          label: "plugin-1\nMy Session\njust now",
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

      await pumpTile(tester, tile(session: session, projectLabel: "demo-app"));

      // The branch stays off the row, for the session detail to show.
      expect(
        tester.getSemantics(find.descendant(of: find.byType(SessionTile), matching: find.byType(MergeSemantics))),
        matchesSemantics(
          label: "plugin-1\nMy Session\njust now\ndemo-app",
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
    testWidgets("a row has exactly the touch row's metrics: 12 px padding, the 16 pt title and the 2 px gap", (
      tester,
    ) async {
      final row = tile(
        session: testSession(title: "My Session", updatedAt: now),
        projectLabel: "demo-app",
      );
      ({double height, double? titleSize, double titleTop, double metaTop}) metrics() {
        final top = tester.getTopLeft(find.byType(SessionTile)).dy;
        return (
          height: tester.getSize(find.byType(SessionTile)).height,
          titleSize: tester.widget<Text>(find.text("My Session")).style?.fontSize,
          titleTop: tester.getTopLeft(find.text("My Session")).dy - top,
          metaTop: tester.getTopLeft(find.text("demo-app")).dy - top,
        );
      }

      await pumpTile(tester, row);
      final touch = metrics();
      await pumpPointerTile(tester, row);

      expect(metrics(), touch);
      // The 18 px meta text sits centred in its 20 px line, 1 px down.
      expect(touch, (height: rowHeight, titleSize: 16.0, titleTop: 12.0, metaTop: 12.0 + 24 + 2 + 1));
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

    testWidgets("a 320-point row with large text shares its width without overflowing", (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpTile(
        tester,
        tile(
          session: scheduled().copyWith(title: "A session title long enough to need the whole row"),
        ),
      );

      expect(tester.takeException(), isNull);
      final resume = tester.getSize(find.byType(SessionScheduledResume));
      expect(resume.width, lessThanOrEqualTo(160));
      expect(tester.getSize(find.textContaining("A session title")).width, greaterThan(0));
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
