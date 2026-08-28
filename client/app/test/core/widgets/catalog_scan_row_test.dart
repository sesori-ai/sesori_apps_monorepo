import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/widgets/catalog_scan_row.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  late int cancelCount;
  late int dismissCount;

  setUp(() {
    cancelCount = 0;
    dismissCount = 0;
  });

  Widget harness(
    CatalogRescanState scan, {
    bool reducedMotion = false,
    PregoDesignSystem? designSystem,
    double? width,
  }) {
    final system = designSystem ?? PregoDesignSystem.light;
    final row = CatalogScanRow(
      scan: scan,
      onCancel: () => cancelCount++,
      onDismiss: () => dismissCount++,
    );
    return MaterialApp(
      theme: ThemeData(
        colorScheme: system.colors.toFlutterColorScheme(),
        textTheme: system.textTheme.asFlutterTextTheme(),
        fontFamily: PregoTextTheme.fontFamily,
        fontFamilyFallback: PregoTextTheme.fontFamilyFallback,
        extensions: [system],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
            child: width == null
                ? row
                : Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(width: width, child: row),
                  ),
          ),
        ),
      ),
    );
  }

  Transform entrance(WidgetTester tester) => tester.widget<Transform>(
    find.byKey(const ValueKey("catalog-scan-row-entrance")),
  );

  double entranceScale(WidgetTester tester) {
    final transform = entrance(tester).transform.storage;
    expect(transform[0], transform[5]);
    return transform[0];
  }

  /// Pumps the row and runs its reveal to completion, so the card is at full
  /// height and hittable. A live row spins forever, so this never settles.
  Future<void> pumpRow(
    WidgetTester tester,
    CatalogRescanState scan, {
    bool reducedMotion = false,
    PregoDesignSystem? designSystem,
    double? width,
  }) async {
    await tester.pumpWidget(
      harness(
        scan,
        reducedMotion: reducedMotion,
        designSystem: designSystem,
        width: width,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group("CatalogScanRow", () {
    testWidgets("takes no space at all while idle", (tester) async {
      await pumpRow(tester, const CatalogRescanState.idle());

      final loc = await AppLocalizations.delegate.load(const Locale("en"));
      expect(find.text(loc.catalogScanRunningTitle), findsNothing);
      expect(tester.getSize(find.byType(CatalogScanRow, skipOffstage: false)).height, 0);
    });

    // The Figma loading component reserves both text lines before a harness
    // reports, so the row does not shove the list down on the first event.
    testWidgets("keeps the same height from starting through running", (tester) async {
      Future<double> heightFor(CatalogRescanState scan) async {
        await pumpRow(tester, scan);
        return tester.getSize(find.byType(CatalogScanRow)).height;
      }

      final starting = await heightFor(const CatalogRescanState.starting(pluginIds: {"codex"}));
      final running = await heightFor(
        const CatalogRescanState.running(activePluginName: "Codex", sessionsSeen: 148, pluginIds: {"codex"}),
      );

      expect(starting, greaterThan(0));
      expect(running, starting);
    });

    testWidgets("reports the scan before any harness has reported progress", (tester) async {
      await pumpRow(tester, const CatalogRescanState.starting(pluginIds: {"codex"}));

      final loc = await AppLocalizations.delegate.load(const Locale("en"));
      expect(find.text(loc.catalogScanRunningTitle), findsOneWidget);
      expect(find.byType(PregoInlineAlertsNotifications), findsOneWidget);
      expect(find.bySemanticsLabel(loc.catalogScanCancel), findsOneWidget);
    });

    testWidgets("fades in from a slight blur and scale with one strong ease-out", (tester) async {
      await tester.pumpWidget(harness(const CatalogRescanState.idle()));
      await tester.pump();

      await tester.pumpWidget(
        harness(const CatalogRescanState.starting(pluginIds: {"codex"})),
      );

      expect(entranceScale(tester), closeTo(0.97, 0.0001));
      expect(find.byKey(const ValueKey("catalog-scan-row-entrance-blur")), findsOneWidget);
      final fade = tester.widget<FadeTransition>(
        find.descendant(of: find.byType(CatalogScanRow), matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, 0);

      var previousScale = entranceScale(tester);
      for (var frame = 0; frame < 13; frame++) {
        await tester.pump(const Duration(milliseconds: 20));
        final scale = entranceScale(tester);
        expect(scale, inInclusiveRange(previousScale, 1));
        previousScale = scale;
      }

      expect(entranceScale(tester), closeTo(1, 0.0001));
      expect(find.byKey(const ValueKey("catalog-scan-row-entrance-blur")), findsNothing);
      expect(fade.opacity.value, closeTo(1, 0.0001));
    });

    testWidgets("does not replay the entrance for progress updates or exit", (tester) async {
      await pumpRow(tester, const CatalogRescanState.starting(pluginIds: {"codex"}));
      expect(entranceScale(tester), 1);

      await tester.pumpWidget(
        harness(
          const CatalogRescanState.running(
            activePluginName: "Codex",
            sessionsSeen: 4,
            pluginIds: {"codex"},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(entranceScale(tester), 1);

      await tester.pumpWidget(harness(const CatalogRescanState.idle()));
      await tester.pump(const Duration(milliseconds: 130));
      expect(entranceScale(tester), 1);
    });

    testWidgets("stops the looping scan graphic when a terminal outcome replaces it", (tester) async {
      await pumpRow(tester, const CatalogRescanState.starting(pluginIds: {"codex"}));

      expect(find.byKey(const ValueKey("prego-deep-scan-loader")), findsOneWidget);
      expect(find.byKey(const ValueKey("prego-deep-scan-beam")), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(
        harness(
          const CatalogRescanState.succeeded(
            harnessCount: 1,
            counts: CatalogRescanCounts.delta(newProjects: 1, newSessions: 2),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey("prego-deep-scan-loader")), findsNothing);
      expect(find.byKey(const ValueKey("prego-deep-scan-beam")), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets("names the harness being scanned and what it has seen", (tester) async {
      await pumpRow(
        tester,
        const CatalogRescanState.running(
          activePluginName: "Codex",
          sessionsSeen: 148,
          pluginIds: {"codex"},
        ),
      );

      expect(find.text("Codex — 148 sessions"), findsOneWidget);
    });

    testWidgets("cancels the scan in flight from the running row", (tester) async {
      await pumpRow(
        tester,
        const CatalogRescanState.running(activePluginName: "Codex", sessionsSeen: 1, pluginIds: {"codex"}),
      );

      final loc = await AppLocalizations.delegate.load(const Locale("en"));
      await tester.tap(find.bySemanticsLabel(loc.catalogScanCancel));

      expect(cancelCount, 1);
      expect(dismissCount, 0);
    });

    testWidgets("matches the 402 by 101 Figma terminal geometry and type rhythm", (tester) async {
      await pumpRow(
        tester,
        const CatalogRescanState.succeeded(
          harnessCount: 2,
          counts: CatalogRescanCounts.delta(newProjects: 2, newSessions: 0),
        ),
        designSystem: PregoDesignSystem.dark,
        width: 402,
      );

      final row = find.byType(CatalogScanRow);
      final card = find.byKey(const ValueKey("catalog-scan-terminal-card"));
      final mark = find.byKey(const ValueKey("catalog-scan-terminal-icon"));
      final action = find.byKey(const ValueKey("catalog-scan-dismiss-action"));

      expect(tester.getSize(row), const Size(402, 101));
      expect(tester.getSize(card), const Size(370, 69));
      expect(tester.getTopLeft(card) - tester.getTopLeft(row), const Offset(16, 16));
      expect(tester.getSize(mark), const Size.square(22));
      expect(tester.getSize(action), const Size(76, 36));

      final container = tester.widget<Container>(card);
      final decoration = container.decoration! as ShapeDecoration;
      final outline = container.foregroundDecoration! as ShapeDecoration;
      final glow = tester.widget<DecoratedBox>(
        find.descendant(
          of: card,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).gradient is RadialGradient,
          ),
        ),
      );
      expect(container.clipBehavior, Clip.antiAlias);
      expect(decoration.color, PregoColorsDark.bgSurface5);
      expect(decoration.shape, isA<RoundedRectangleBorder>());
      expect(
        (decoration.shape as RoundedRectangleBorder).borderRadius,
        const BorderRadius.all(Radius.circular(PregoRadius.x4l)),
      );
      expect((outline.shape as RoundedRectangleBorder).side.color, PregoColorsDark.borderPrimary);
      final gradient = (glow.decoration as BoxDecoration).gradient! as RadialGradient;
      expect(gradient.center, Alignment.topCenter);
      expect(gradient.radius, 1);
      expect(gradient.stops, const [0, 0.6, 1]);
      expect(gradient.colors.last, PregoColorsDark.bgSuccessSecondary.withValues(alpha: 0.2));

      for (final label in ["Scan complete", "2 new projects"]) {
        final style = tester.widget<Text>(find.text(label)).style!;
        expect(style.fontSize, 14);
        expect(style.height, closeTo(20 / 14, 0.0001));
        expect(style.fontWeight, FontWeight.w500);
      }
    });

    testWidgets("maps each terminal outcome to its exact Figma tone", (tester) async {
      final cases =
          <
            ({
              CatalogRescanState scan,
              Color accent,
              Color mark,
              Color action,
            })
          >[
            (
              scan: const CatalogRescanState.succeeded(
                harnessCount: 2,
                counts: CatalogRescanCounts.delta(newProjects: 2, newSessions: 0),
              ),
              accent: PregoColorsDark.bgSuccessSecondary,
              mark: PregoColorsDark.textSuccessPrimary,
              action: PregoColorsDark.textSuccessPrimary,
            ),
            (
              scan: const CatalogRescanState.partlyFailed(succeededCount: 2, failedCount: 1),
              accent: PregoColorsDark.bgWarningSecondary,
              mark: PregoColorsDark.fgWarningSecondary,
              action: PregoColorsDark.textWarningPrimary,
            ),
            (
              scan: const CatalogRescanState.failed(harnessCount: 3),
              accent: PregoColorsDark.bgErrorSolid,
              mark: PregoColorsDark.fgErrorPrimary,
              action: PregoColorsDark.textErrorPrimary,
            ),
          ];

      for (final outcome in cases) {
        await pumpRow(
          tester,
          outcome.scan,
          designSystem: PregoDesignSystem.dark,
          width: 402,
        );

        final card = find.byKey(const ValueKey("catalog-scan-terminal-card"));
        final glow = tester.widget<DecoratedBox>(
          find.descendant(
            of: card,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is DecoratedBox &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).gradient is RadialGradient,
            ),
          ),
        );
        final gradient = (glow.decoration as BoxDecoration).gradient! as RadialGradient;
        expect(gradient.colors.last, outcome.accent.withValues(alpha: 0.2));

        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(const ValueKey("catalog-scan-terminal-icon")),
            matching: find.byType(Icon),
          ),
        );
        expect(icon.color, outcome.mark);

        final dismiss = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey("catalog-scan-dismiss-action")),
            matching: find.text("Dismiss"),
          ),
        );
        expect(dismiss.style!.color, outcome.action);
      }
    });

    testWidgets(
      "uses the same 24px platform silhouette for every terminal outcome",
      (tester) async {
        final outcomes = <CatalogRescanState>[
          const CatalogRescanState.succeeded(
            harnessCount: 2,
            counts: CatalogRescanCounts.delta(newProjects: 2, newSessions: 5),
          ),
          const CatalogRescanState.partlyFailed(succeededCount: 2, failedCount: 1),
          const CatalogRescanState.failed(harnessCount: 3),
          const CatalogRescanState.unsupported(),
          const CatalogRescanState.noHarness(),
        ];

        for (final outcome in outcomes) {
          await pumpRow(
            tester,
            outcome,
            designSystem: PregoDesignSystem.dark,
            width: 402,
          );

          final finder = find.byKey(const ValueKey("catalog-scan-terminal-card"));
          final card = tester.widget<Container>(finder);
          final decoration = card.decoration! as ShapeDecoration;
          final outline = card.foregroundDecoration! as ShapeDecoration;
          final platform = Theme.of(tester.element(finder)).platform;
          final radius = switch (decoration.shape) {
            RoundedSuperellipseBorder(:final borderRadius) => borderRadius,
            RoundedRectangleBorder(:final borderRadius) => borderRadius,
            final shape => throw TestFailure("Unexpected Deep Scan shape: $shape"),
          };

          expect(card.clipBehavior, Clip.antiAlias);
          expect(radius, const BorderRadius.all(Radius.circular(PregoRadius.x4l)));
          expect(
            decoration.shape,
            platform == TargetPlatform.iOS ? isA<RoundedSuperellipseBorder>() : isA<RoundedRectangleBorder>(),
          );
          expect(outline.shape.runtimeType, decoration.shape.runtimeType);
          expect((outline.shape as OutlinedBorder).side.color, PregoColorsDark.borderPrimary);
        }
      },
      variant: const TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android}),
    );

    testWidgets("drops the projects clause when nothing new landed in one", (tester) async {
      await pumpRow(
        tester,
        const CatalogRescanState.succeeded(
          harnessCount: 2,
          counts: CatalogRescanCounts.delta(newProjects: 0, newSessions: 3),
        ),
      );

      expect(find.text("3 new sessions"), findsOneWidget);
    });

    testWidgets("joins both clauses when new items landed in a new project", (tester) async {
      await pumpRow(
        tester,
        const CatalogRescanState.succeeded(
          harnessCount: 2,
          counts: CatalogRescanCounts.delta(newProjects: 2, newSessions: 5),
        ),
      );

      expect(find.text("5 new sessions in 2 new projects"), findsOneWidget);
    });

    testWidgets("says nothing was new rather than reporting a zero", (tester) async {
      await pumpRow(
        tester,
        const CatalogRescanState.succeeded(
          harnessCount: 1,
          counts: CatalogRescanCounts.delta(newProjects: 0, newSessions: 0),
        ),
      );

      expect(find.text("No new sessions"), findsOneWidget);
    });

    // The sessions clause is dropped rather than joined at zero, so the line
    // stays a noun phrase instead of reading "No new sessions in 2 new projects".
    testWidgets("leads with projects when a scan turned up no new session", (tester) async {
      await pumpRow(
        tester,
        const CatalogRescanState.succeeded(
          harnessCount: 1,
          counts: CatalogRescanCounts.delta(newProjects: 2, newSessions: 0),
        ),
      );

      expect(find.text("2 new projects"), findsOneWidget);
    });

    // A harness that omitted its delta makes the whole row fall back, so the
    // wording must not imply any of the counted items is new.
    testWidgets("reports published totals as totals when no delta is available", (tester) async {
      await pumpRow(
        tester,
        const CatalogRescanState.succeeded(
          harnessCount: 2,
          counts: CatalogRescanCounts.totals(projects: 12, sessions: 148),
        ),
      );

      expect(find.text("148 sessions in 12 projects"), findsOneWidget);
      expect(find.textContaining("new"), findsNothing);
    });

    testWidgets("names how many harnesses failed out of the whole scan", (tester) async {
      await pumpRow(tester, const CatalogRescanState.partlyFailed(succeededCount: 2, failedCount: 1));

      expect(find.text("Scanning finished"), findsOneWidget);
      expect(find.text("1 of 3 harnesses could not be found"), findsOneWidget);
    });

    // The bridge's raw error text is never lifted into client state, so the row
    // points at the log that has it.
    testWidgets("points at the bridge log when every harness failed", (tester) async {
      await pumpRow(tester, const CatalogRescanState.failed(harnessCount: 2));

      final loc = await AppLocalizations.delegate.load(const Locale("en"));
      expect(find.text(loc.catalogScanFailedTitle), findsOneWidget);
      expect(find.text(loc.catalogScanFailedDetail), findsOneWidget);
      expect(find.text("Check bridge logs"), findsOneWidget);
    });

    testWidgets("explains an older bridge instead of reporting a failure", (tester) async {
      await pumpRow(tester, const CatalogRescanState.unsupported());

      final loc = await AppLocalizations.delegate.load(const Locale("en"));
      expect(find.text(loc.catalogScanUnsupportedTitle), findsOneWidget);
      expect(find.text(loc.catalogScanUnsupportedDetail), findsOneWidget);
    });

    testWidgets("says there is nothing to scan when no harness is ready", (tester) async {
      await pumpRow(tester, const CatalogRescanState.noHarness());

      final loc = await AppLocalizations.delegate.load(const Locale("en"));
      expect(find.text(loc.catalogScanNoHarnessTitle), findsOneWidget);
      expect(find.text(loc.catalogScanNoHarnessDetail), findsOneWidget);
    });

    // The running row's session count changes with every enumerated session, so
    // announcing it would interrupt a screen reader throughout a long scan.
    testWidgets("announces every state except the one whose count keeps moving", (tester) async {
      Future<bool?> announcesFor(CatalogRescanState scan) async {
        await pumpRow(tester, scan);
        return tester
            .widget<Semantics>(
              find.descendant(of: find.byType(CatalogScanRow), matching: find.byType(Semantics)).first,
            )
            .properties
            .liveRegion;
      }

      expect(await announcesFor(const CatalogRescanState.starting(pluginIds: {"codex"})), isTrue);
      expect(await announcesFor(const CatalogRescanState.failed(harnessCount: 1)), isTrue);
      expect(
        await announcesFor(
          const CatalogRescanState.running(activePluginName: "Codex", sessionsSeen: 9, pluginIds: {"codex"}),
        ),
        isFalse,
      );
    });

    // SizeTransition only changes layout, so a retained card would keep its
    // labels and its live action button reachable by keyboard at zero height.
    testWidgets("unmounts the card once it has folded away", (tester) async {
      await pumpRow(tester, const CatalogRescanState.failed(harnessCount: 1));
      final loc = await AppLocalizations.delegate.load(const Locale("en"));
      expect(find.text(loc.catalogScanDismiss, skipOffstage: false), findsOneWidget);

      await pumpRow(tester, const CatalogRescanState.idle());

      expect(
        find.text(loc.catalogScanDismiss, skipOffstage: false),
        findsNothing,
        reason: "an invisible action must not stay in the tree",
      );
      expect(
        find.byKey(const ValueKey("catalog-scan-dismiss-action"), skipOffstage: false),
        findsNothing,
      );
    });

    testWidgets("arrives without a transition when the OS asks for reduced motion", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: CatalogScanRow(
                  scan: const CatalogRescanState.idle(),
                  onCancel: () => cancelCount++,
                  onDismiss: () => dismissCount++,
                ),
              ),
            ),
          ),
        ),
      );
      // Rebuilt in place and pumped exactly one frame — far short of the 260ms
      // transition, so any height at all means it never ran.
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: CatalogScanRow(
                  scan: const CatalogRescanState.starting(pluginIds: {"codex"}),
                  onCancel: () => cancelCount++,
                  onDismiss: () => dismissCount++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      final afterOneFrame = tester.getSize(find.byType(CatalogScanRow, skipOffstage: false)).height;
      await tester.pump(const Duration(milliseconds: 400));
      final settled = tester.getSize(find.byType(CatalogScanRow, skipOffstage: false)).height;

      expect(settled, greaterThan(0));
      expect(
        afterOneFrame,
        settled,
        reason: "reduced motion means the row is simply there, not part-way through arriving",
      );
      expect(entranceScale(tester), 1);
    });

    testWidgets("arrives without a transition under iOS Reduce Motion", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        reduceMotion: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(harness(const CatalogRescanState.idle()));
      await tester.pump();
      await tester.pumpWidget(
        harness(const CatalogRescanState.starting(pluginIds: {"codex"})),
      );
      await tester.pump(const Duration(milliseconds: 16));

      final afterOneFrame = tester.getSize(find.byType(CatalogScanRow, skipOffstage: false)).height;
      await tester.pump(const Duration(milliseconds: 400));
      final settled = tester.getSize(find.byType(CatalogScanRow, skipOffstage: false)).height;

      expect(afterOneFrame, settled);
      expect(entranceScale(tester), 1);
    });

    testWidgets("settles an active entrance when iOS Reduce Motion turns on", (tester) async {
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(harness(const CatalogRescanState.idle()));
      await tester.pump();
      await tester.pumpWidget(
        harness(const CatalogRescanState.starting(pluginIds: {"codex"})),
      );
      await tester.pump(const Duration(milliseconds: 80));
      expect(entranceScale(tester), isNot(1));

      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        reduceMotion: true,
      );
      await tester.pump();

      expect(entranceScale(tester), 1);
    });

    testWidgets("dismisses a finished scan without cancelling anything", (tester) async {
      await pumpRow(tester, const CatalogRescanState.failed(harnessCount: 1));

      final loc = await AppLocalizations.delegate.load(const Locale("en"));
      await tester.tap(find.text(loc.catalogScanDismiss));

      expect(dismissCount, 1);
      expect(cancelCount, 0);
    });
  });
}
