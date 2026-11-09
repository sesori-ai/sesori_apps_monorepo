import "dart:math";

import "package:clock/clock.dart";
import "package:flutter/gestures.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

/// A session row is the harness logo, the title with its status mark after it
/// and when it last changed, over a tertiary meta line: any state that needs
/// words, then the project and a count of background tasks. Under a pointer the
/// logo ends the meta line instead of leading the title.
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
      onTap: () {},
      menuEntries: () => const [],
      onArchive: onArchive ?? () {},
      onDelete: () {},
      onToggleUnread: onToggleUnread ?? () {},
    );
  }

  Future<void> pumpTile(WidgetTester tester, Widget row, {Widget Function(Widget child)? wrap}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [if (wrap == null) PregoDesignSystem.light else PregoDesignSystem.desktopLight]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Material(child: Column(children: [if (wrap == null) row else wrap(row)])),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> pumpPointerTile(WidgetTester tester, Widget row) => pumpTile(
    tester,
    row,
    wrap: (child) => PregoInteractionScope(mode: PregoInteractionMode.pointer, child: child),
  );

  FontWeight? titleWeight(WidgetTester tester, String title) => tester.widget<Text>(find.text(title)).style?.fontWeight;

  /// Whether the row's sparkle is twinkling. `tester.hasRunningAnimations` is
  /// avoided for symmetry with the project list's states test: the sparkle's
  /// contract is read off the widget, and that the flag really does start and
  /// stop the loop is PregoAiLoader's own test.
  bool sparkleTwinkles(WidgetTester tester) => tester.widget<PregoAiLoader>(find.byType(PregoAiLoader)).animate;

  /// Whether the harness logo is lit, in its own colours and breathing, rather
  /// than resting as a grey glyph. It is always exactly one of the two.
  bool logoLit(WidgetTester tester) {
    final logo = find.byType(PregoBrandLogo);
    final breathing = find.ancestor(of: logo, matching: find.byType(PregoBreathing)).evaluate().isNotEmpty;
    final grey = find.ancestor(of: logo, matching: find.byType(ColorFiltered)).evaluate().isNotEmpty;
    expect(breathing, !grey, reason: "a logo is either lit or grey");
    return breathing;
  }

  double logoOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(find.descendant(of: find.byType(PregoBreathing), matching: find.byType(FadeTransition)))
      .opacity
      .value;

  /// The background task count's paragraph: the glyph's placeholder, then the
  /// number.
  Finder backgroundCount(int count) => find.text("\u{FFFC}$count");

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
        // A plain live turn carries no words, the twinkle and the lit logo
        // being the signal.
        expect(find.text("Running"), findsNothing);
        if (pointer) {
          // Just before the time, and the title starts at the row's edge.
          expect(find.text("now"), findsOneWidget);
          expect(tester.getTopLeft(find.text("now")).dx - tester.getTopRight(sparkle).dx, 8);
          expect(tester.getTopLeft(find.text("My Session")).dx, 14);
        } else {
          // Right beside a short title, well ahead of the time.
          expect(tester.getTopLeft(sparkle).dx - tester.getTopRight(find.text("My Session")).dx, 4);
          expect(tester.getTopRight(sparkle).dx, lessThan(tester.getTopLeft(find.text("now")).dx));
          expect(find.text("now"), findsOneWidget);
        }
      });

      testWidgets("an unread session carries its mark and weights its title", (tester) async {
        await pump(
          tester,
          tile(
            session: testSession(title: "My Session", updatedAt: now),
            unseen: true,
          ),
        );

        // The resting star: the same mark as working, standing still.
        expect(sparkleTwinkles(tester), isFalse);
        expect(titleWeight(tester, "My Session"), FontWeight.w500);
        expect(find.text("now"), findsOneWidget);
      });

      testWidgets("a waiting session says Waiting in amber, with an amber dot under a finger", (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(
          tester,
          tile(
            session: testSession(title: "My Session", updatedAt: now),
            awaitingInput: true,
          ),
        );

        expect(find.byType(PregoAiLoader), findsNothing);
        final dot = find.descendant(
          of: find.byType(SessionTile),
          matching: find.byWidgetPredicate(
            (widget) => switch (widget) {
              Container(decoration: BoxDecoration(shape: BoxShape.circle)) => true,
              _ => false,
            },
          ),
        );
        // Heard once, from the mark; the word stays silent.
        expect(find.bySemanticsLabel(RegExp("Awaiting input")), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp("Waiting")), findsNothing);
        expect(tester.widget<Text>(find.text("Waiting")).style?.color, colors.smallWarningText);
        if (pointer) {
          expect((tester.widget<Container>(dot).decoration as BoxDecoration?)?.color, colors.pointerWarningFill);
        } else {
          expect((tester.widget<Container>(dot).decoration as BoxDecoration?)?.color, colors.fgWarningPrimary);
        }
        expect(find.text("now"), findsOneWidget);
        semantics.dispose();
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

      testWidgets("the logo leads 12 px in under a finger and ends the meta line under a pointer, with no branch", (
        tester,
      ) async {
        await pump(
          tester,
          tile(
            session: testSession(title: "My Session", branchName: "sesori/add-search", updatedAt: now),
            projectLabel: "demo-app",
          ),
        );

        if (pointer) {
          // The row's text shares one edge, and the logo is the meta line's
          // last item, ending under the time.
          final logo = find.byType(PregoBrandLogo);
          expect(tester.getTopLeft(find.text("demo-app")).dx, tester.getTopLeft(find.text("My Session")).dx);
          expect(tester.getSize(logo), const Size.square(14));
          expect(tester.getTopRight(logo).dx, tester.getTopRight(find.text("now")).dx);
          expect(tester.getCenter(logo).dy, closeTo(tester.getCenter(find.text("demo-app")).dy, 0.5));
        } else {
          expect(tester.getTopLeft(find.byType(PregoBrandLogo)).dx, 12);
          expect(tester.getTopLeft(find.text("demo-app")).dx, 12);
        }
        expect(
          tester.widget<Text>(find.text("demo-app")).style?.color,
          pointer ? colors.textSecondary : colors.textTertiary,
        );
        // The time keeps its inset from the trailing edge.
        expect(tester.getTopRight(find.text("now")).dx, 800 - (pointer ? 14 : 16));
        expect(find.text("sesori/add-search"), findsNothing);

        if (pointer) {
          // Without a project the logo still ends the line.
          await pump(
            tester,
            tile(
              session: testSession(title: "My Session", updatedAt: now),
            ),
          );
          expect(tester.getTopRight(find.byType(PregoBrandLogo)).dx, 800 - 14);
        }
      });

      testWidgets("the logo is lit only while an agent works: not while waiting, nor for being open", (tester) async {
        final session = testSession(title: "My Session", updatedAt: now);
        for (final (name, row, lit) in [
          ("quiet", tile(session: session), false),
          ("unread", tile(session: session, unseen: true), false),
          ("open", tile(session: session, selected: true), false),
          ("waiting", tile(session: session, awaitingInput: true), false),
          ("waiting while counted as running", tile(session: session, isRunning: true, awaitingInput: true), false),
          ("running", tile(session: session, isRunning: true), true),
          ("running and open", tile(session: session, isRunning: true, selected: true), true),
          ("retrying", tile(session: session, isRunning: true, isRetrying: true), true),
        ]) {
          await pump(tester, row);
          expect(logoLit(tester), lit, reason: name);
        }
      });

      testWidgets("a lit logo breathes, and holds still at full strength under reduced motion", (tester) async {
        await withClock(Clock(() => tester.binding.clock.now()), () async {
          await pump(tester, tile(session: testSession(title: "My Session"), isRunning: true));
          final breath = <double>[];
          for (var step = 0; step < 8; step++) {
            await tester.pump(const Duration(milliseconds: 200));
            breath.add(logoOpacity(tester));
          }
          expect(breath.reduce(min), lessThan(0.5));
          expect(breath.reduce(max), greaterThan(0.9));

          tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
            reduceMotion: true,
          );
          addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
          await tester.pump();
          for (var step = 0; step < 4; step++) {
            await tester.pump(const Duration(milliseconds: 200));
            expect(logoOpacity(tester), 1);
          }
          expect(logoLit(tester), isTrue);
        });
      });

      testWidgets("a plain running row says Running only to assistive technology", (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(
          tester,
          tile(
            session: testSession(title: "My Session", updatedAt: now),
            isRunning: true,
          ),
        );

        expect(find.text("Running"), findsNothing);
        expect(find.bySemanticsLabel(RegExp("My Session\nRunning\n")), findsOneWidget);
        semantics.dispose();
      });

      testWidgets("background tasks are a quiet count after the project, which waiting and retrying outrank", (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        final session = testSession(title: "My Session", updatedAt: now);
        await pump(tester, tile(session: session, projectLabel: "demo-app", isRunning: true, backgroundTaskCount: 2));

        // A stack glyph and the number, in the meta line's own type.
        final glyph = find.byIcon(TablerRegular.stack_2);
        final metaColor = pointer ? colors.textSecondary : colors.textTertiary;
        expect(tester.getSize(glyph), const Size.square(12));
        expect(tester.widget<Icon>(glyph).color, metaColor);
        final count = tester.widget<Text>(backgroundCount(2));
        expect((count.style?.color, count.style?.fontWeight), (metaColor, FontWeight.w400));
        expect(tester.getTopLeft(glyph).dx, greaterThan(tester.getTopRight(find.text("demo-app")).dx));
        expect(find.textContaining("background task"), findsNothing);
        // Assistive technology hears the words, and a pointer finds them in a tooltip.
        expect(find.bySemanticsLabel(RegExp("2 background tasks")), findsOneWidget);
        expect(
          find.byWidgetPredicate((widget) => widget is Tooltip && widget.message == "2 background tasks"),
          pointer ? findsOneWidget : findsNothing,
        );
        if (pointer) {
          expect(
            tester.getTopRight(backgroundCount(2)).dx,
            lessThan(tester.getTopLeft(find.byType(PregoBrandLogo)).dx),
          );
        }

        for (final row in [
          tile(
            session: session,
            projectLabel: "demo-app",
            isRunning: true,
            awaitingInput: true,
            backgroundTaskCount: 2,
          ),
          tile(session: session, projectLabel: "demo-app", isRunning: true, isRetrying: true, backgroundTaskCount: 2),
        ]) {
          await pump(tester, row);
          expect(glyph, findsNothing);
        }
        semantics.dispose();
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

  testWidgets("retrying leads the meta line in its colour", (tester) async {
    await pumpTile(tester, tile(session: testSession(title: "My Session"), isRunning: true, isRetrying: true));
    expect(tester.widget<Text>(find.text("Running (retrying)")).style?.color, colors.fgErrorPrimary);
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

    for (final row in [
      tile(session: session, projectLabel: "demo-app", awaitingInput: true),
      tile(session: session, projectLabel: "a-very-long-project-name", isRunning: true, backgroundTaskCount: 12),
    ]) {
      await pumpTile(tester, row);
      expect(tester.takeException(), isNull);
      await pumpPointerTile(tester, row);
      expect(tester.takeException(), isNull);
    }
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
    testWidgets(
      "a row tightens to a 13.5 pt title over a 12 pt meta line in 6 px padding, inset 1 px from its neighbours",
      (
        tester,
      ) async {
        final row = tile(
          session: testSession(title: "My Session", updatedAt: now),
          projectLabel: "demo-app",
        );
        ({double height, double? titleSize, double? metaSize, double? timeSize, double titleTop, double metaTop})
        metrics() {
          final top = tester.getTopLeft(find.byType(SessionTile)).dy;
          return (
            height: tester.getSize(find.byType(SessionTile)).height,
            titleSize: tester.widget<Text>(find.text("My Session")).style?.fontSize,
            metaSize: tester.widget<Text>(find.text("demo-app")).style?.fontSize,
            timeSize: tester.widget<Text>(find.text("now")).style?.fontSize,
            titleTop: tester.getTopLeft(find.text("My Session")).dy - top,
            metaTop: tester.getTopLeft(find.text("demo-app")).dy - top,
          );
        }

        await pumpTile(tester, row);
        final touch = metrics();
        await pumpPointerTile(tester, row);
        // The theme eases from the touch scale to the desktop one.
        await tester.pump(const Duration(milliseconds: 300));

        // The 18 px meta text sits centred in its 20 px line, 1 px down.
        expect(touch, (
          height: rowHeight,
          titleSize: 16.0,
          metaSize: 12.0,
          timeSize: 12.0,
          titleTop: 12.0,
          metaTop: 12.0 + 24 + 2 + 1,
        ));
        // A 19 px title, 2 px apart from a 16 px meta line; the time in the meta line's type.
        expect(metrics(), (
          height: 51.0,
          titleSize: 13.5,
          metaSize: 12.0,
          timeSize: 12.0,
          titleTop: 7.0,
          metaTop: 7.0 + 19 + 2,
        ));
        expect(SessionTileSkeleton.heightOf(pointer: true), 51);
        expect(find.text("now"), findsOneWidget);
      },
    );

    testWidgets("every row is as tall, with its lines and logo in the same place, whatever its meta line holds", (
      tester,
    ) async {
      final session = testSession(title: "My Session", updatedAt: now);
      final continueAt = DateTime.now().add(const Duration(minutes: 1)).millisecondsSinceEpoch;
      final scheduled = session.copyWith(
        autoContinuation: SessionAutoContinuationView(
          enabled: true,
          availability: .conditional,
          status: SessionAutoContinuationStatus.resetKnown(resetAt: continueAt, continueAt: continueAt),
        ),
      );
      final variants = {
        "nothing on the meta line": tile(session: session),
        "a project": tile(session: session, projectLabel: "demo-app"),
        "running": tile(session: session, isRunning: true),
        "a project and background tasks": tile(
          session: session,
          projectLabel: "demo-app",
          isRunning: true,
          backgroundTaskCount: 3,
        ),
        "background tasks alone": tile(session: session, isRunning: true, backgroundTaskCount: 3),
        "waiting": tile(session: session, projectLabel: "demo-app", awaitingInput: true),
        "waiting alone": tile(session: session, awaitingInput: true),
        "retrying": tile(session: session, projectLabel: "demo-app", isRunning: true, isRetrying: true),
        "unread": tile(session: session, projectLabel: "demo-app", unseen: true),
        "open": tile(session: session, projectLabel: "demo-app", selected: true),
        "a scheduled resume": tile(session: scheduled, projectLabel: "demo-app"),
        "a launching session": PendingSessionLaunchTile(
          launch: LaunchingSession(
            launchId: "launch",
            projectId: "project",
            pluginId: "claude",
            startedAt: DateTime.now(),
            title: "My Session",
          ),
        ),
      };
      final layouts = <String, ({double height, double titleTop, double logoCentre})>{};
      for (final MapEntry(key: name, value: row) in variants.entries) {
        await pumpPointerTile(tester, row);
        final rowBox = find.byType(row.runtimeType);
        final top = tester.getTopLeft(rowBox).dy;
        layouts[name] = (
          height: tester.getSize(rowBox).height,
          titleTop: tester.getTopLeft(find.text("My Session")).dy - top,
          logoCentre: tester.getCenter(find.byType(PregoBrandLogo)).dy - top,
        );
      }

      // The launching row, pumped last, counts as running.
      expect(logoLit(tester), isTrue);
      // The meta line's 16 px box centres at 7 + 19 + 2 + 8.
      expect(layouts, {for (final name in variants.keys) name: (height: 51.0, titleTop: 7.0, logoCentre: 36.0)});
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
      // Over the meta line's end, centred on it.
      expect(tester.getCenter(find.byKey(archive)).dy, tester.getCenter(find.byType(PregoBrandLogo)).dy);

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
