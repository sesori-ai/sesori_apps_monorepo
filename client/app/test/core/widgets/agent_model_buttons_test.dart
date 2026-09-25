import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart"
    show
        FastModeControl,
        FastModeToggleApply,
        FastModeToggleConfirmCacheReset,
        FastModeToggleDecision,
        FastModeToggleUnavailable;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

/// The agents a real project reports — a handful, each with a description long
/// enough to run past the row and ellipsize.
final _agents = [
  _agent(name: "build", description: "The default agent. Executes tools and edits files."),
  _agent(name: "plan", description: "Plan mode. Disallows all edit tools."),
  _agent(name: "aristotle-plan-review", description: "Reviews architecture-bearing development plans."),
  _agent(name: "aristotle-impl-review", description: "Reviews architecture-bearing production changes."),
];

AgentInfo _agent({required String name, required String description}) =>
    AgentInfo(name: name, description: description, model: null, mode: AgentMode.all);

Finder _menuItem(String label) => find.descendant(
  of: find.byType(SingleChildScrollView),
  matching: find.widgetWithText(InkWell, label),
);

Widget _buildApp({required List<AgentInfo> agents, required void Function(String) onAgentSelected}) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      // Bottom-aligned, like the composer the pickers actually live in.
      body: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AgentModelButtons(
            surfaceStyle: PregoComposerSurfaceStyle.subtle,
            agents: agents,
            selectedAgent: "aristotle-impl-review",
            onAgentSelected: onAgentSelected,
            providers: const [],
            selectedAgentModel: null,
            onModelSelected: ({required providerID, required modelID}) {},
            availableVariants: const [],
            onVariantSelected: (_) {},
            fastModeControl: FastModeControl.hidden,
            decideFastModeToggle: () => null,
            onFastModeChanged: (_) {},
            compact: false,
            trailing: const [],
          ),
        ],
      ),
    ),
  );
}

const _variants = [
  SessionVariant(id: "max"),
  SessionVariant(id: "xhigh"),
  SessionVariant(id: "high"),
  SessionVariant(id: "medium"),
  SessionVariant(id: "low"),
  SessionVariant(id: "minimal"),
];

Widget _buildVariantApp({required ValueChanged<SessionVariant> onVariantSelected}) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AgentModelButtons(
            surfaceStyle: PregoComposerSurfaceStyle.subtle,
            agents: const [],
            selectedAgent: null,
            onAgentSelected: (_) {},
            providers: const [],
            // The menu opens at the strongest end even if a low effort is selected.
            selectedAgentModel: const AgentModel(providerID: "example", modelID: "model", variant: "minimal"),
            onModelSelected: ({required providerID, required modelID}) {},
            availableVariants: _variants,
            onVariantSelected: onVariantSelected,
            fastModeControl: FastModeControl.hidden,
            decideFastModeToggle: () => null,
            onFastModeChanged: (_) {},
            compact: false,
            trailing: const [],
          ),
          // The prompt field sits below the picker row in the chat composer.
          const SizedBox(height: 120),
        ],
      ),
    ),
  );
}

Widget _buildFastModeApp({
  required PregoDesignSystem designSystem,
  required FastModeControl control,
  required FastModeToggleDecision decision,
  required ValueChanged<bool> onFastModeChanged,
}) {
  return MaterialApp(
    theme: ThemeData(extensions: [designSystem]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AgentModelButtons(
            surfaceStyle: PregoComposerSurfaceStyle.subtle,
            agents: const [],
            selectedAgent: null,
            onAgentSelected: (_) {},
            providers: const [],
            selectedAgentModel: const AgentModel(providerID: "anthropic", modelID: "opus", variant: "high"),
            onModelSelected: ({required providerID, required modelID}) {},
            availableVariants: const [SessionVariant(id: "high")],
            onVariantSelected: (_) {},
            fastModeControl: control,
            decideFastModeToggle: () => decision,
            onFastModeChanged: onFastModeChanged,
            compact: false,
            trailing: const [],
          ),
        ],
      ),
    ),
  );
}

void main() {
  group("Fast mode pill", () {
    Finder pill() => find.bySemanticsLabel("Fast mode");

    testWidgets("is hidden when the model has no fast mode", (tester) async {
      await tester.pumpWidget(
        _buildFastModeApp(
          designSystem: PregoDesignSystem.light,
          control: FastModeControl.hidden,
          decision: const FastModeToggleApply(fastMode: true),
          onFastModeChanged: (_) {},
        ),
      );

      expect(find.byIcon(TablerRegular.bolt), findsNothing);
      expect(find.byIcon(TablerRegular.bolt_off), findsNothing);
    });

    for (final (name, designSystem, expected) in [
      ("dark", PregoDesignSystem.dark, const Color(0xFFFEC84B)),
      ("light", PregoDesignSystem.light, const Color(0xFFF79009)),
    ]) {
      testWidgets("is tinted yellow while on in $name theme and applies a cold switch directly", (tester) async {
        final changes = <bool>[];
        await tester.pumpWidget(
          _buildFastModeApp(
            designSystem: designSystem,
            control: FastModeControl.on,
            decision: const FastModeToggleApply(fastMode: false),
            onFastModeChanged: changes.add,
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(TablerRegular.bolt));
        expect(icon.color, expected);
        expect(tester.getSemantics(pill()), isSemantics(isButton: true, isToggled: true));

        await tester.tap(pill());
        await tester.pumpAndSettle();
        expect(changes, [false]);
      });
    }

    testWidgets("is dimmed when unavailable and a tap explains why", (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        _buildFastModeApp(
          designSystem: PregoDesignSystem.light,
          control: FastModeControl.unavailable,
          decision: const FastModeToggleUnavailable(reason: FastModeUnavailableReason.notOnPlan),
          onFastModeChanged: changes.add,
        ),
      );
      final context = tester.element(find.byType(AgentModelButtons));
      final loc = AppLocalizations.of(context)!;

      expect(tester.widget<Icon>(find.byIcon(TablerRegular.bolt_off)).color, context.prego.colors.fgDisabled);

      await tester.tap(pill());
      await tester.pump();
      expect(find.text(loc.sessionDetailFastModeUnavailableTitle), findsOneWidget);
      expect(find.text(loc.sessionDetailFastModeUnavailableNotOnPlan), findsOneWidget);
      expect(changes, isEmpty);
      await tester.pumpAndSettle(const Duration(seconds: 4));
    });

    testWidgets("asks before dropping a warm prompt cache", (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        _buildFastModeApp(
          designSystem: PregoDesignSystem.light,
          control: FastModeControl.off,
          decision: const FastModeToggleConfirmCacheReset(fastMode: true),
          onFastModeChanged: changes.add,
        ),
      );
      final loc = AppLocalizations.of(tester.element(find.byType(AgentModelButtons)))!;

      await tester.tap(pill());
      await tester.pumpAndSettle();
      expect(find.text(loc.sessionDetailFastModeConfirmTitle), findsOneWidget);
      expect(find.text(loc.sessionDetailFastModeConfirmEnableBody), findsOneWidget);
      expect(changes, isEmpty);
    });
  });

  group("Variant picker", () {
    const platforms = TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android, TargetPlatform.macOS});

    testWidgets("lists efforts lowest to highest with the heading at the top", (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final selected = <SessionVariant>[];
      await tester.pumpWidget(_buildVariantApp(onVariantSelected: selected.add));
      await tester.tap(find.widgetWithText(PregoPickerButton, "minimal"));
      await tester.pumpAndSettle();

      final displayOrder = _variants.reversed.toList();
      for (var index = 1; index < displayOrder.length; index++) {
        expect(
          tester.getTopLeft(_menuItem(displayOrder[index - 1].id)).dy,
          lessThan(tester.getTopLeft(_menuItem(displayOrder[index].id)).dy),
        );
      }
      final loc = AppLocalizations.of(tester.element(find.byType(AgentModelButtons)))!;
      expect(
        tester.getBottomLeft(find.text(loc.sessionDetailPickerVariant.toUpperCase())).dy,
        lessThanOrEqualTo(tester.getTopLeft(_menuItem("minimal")).dy),
      );
      expect(tester.state<ScrollableState>(find.byType(Scrollable)).position.maxScrollExtent, 0);
      expect(find.descendant(of: _menuItem("minimal"), matching: find.byIcon(TablerRegular.check)), findsOneWidget);

      await tester.tap(_menuItem("xhigh"));
      await tester.pumpAndSettle();
      expect(selected, [const SessionVariant(id: "xhigh")]);
      expect(_menuItem("max"), findsNothing);
    }, variant: platforms);

    testWidgets("opens cramped menus at max and scrolls toward the lowest efforts", (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 216);
      addTearDown(tester.view.reset);
      final selected = <SessionVariant>[];
      await tester.pumpWidget(_buildVariantApp(onVariantSelected: selected.add));
      await tester.tap(find.widgetWithText(PregoPickerButton, "minimal"));
      await tester.pumpAndSettle();

      final scrollView = find.byType(SingleChildScrollView);
      final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(position.maxScrollExtent, greaterThan(0));
      expect(_menuItem("max").hitTestable(), findsOneWidget);
      expect(_menuItem("xhigh").hitTestable(), findsOneWidget);
      expect(_menuItem("minimal").hitTestable(), findsNothing);
      expect(tester.getRect(_menuItem("max")).bottom, tester.getRect(scrollView).bottom);

      await tester.drag(scrollView, const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(_menuItem("minimal").hitTestable(), findsOneWidget);
      await tester.tap(_menuItem("minimal"));
      await tester.pumpAndSettle();
      expect(selected, [const SessionVariant(id: "minimal")]);
      expect(_menuItem("max"), findsNothing);

      // Scrolling a previous opening does not hide the strongest end next time.
      await tester.tap(find.widgetWithText(PregoPickerButton, "minimal"));
      await tester.pumpAndSettle();
      expect(_menuItem("max").hitTestable(), findsOneWidget);
      expect(_menuItem("minimal").hitTestable(), findsNothing);
    }, variant: platforms);
  });

  group("Agent picker", () {
    testWidgets("appears only when there is more than one agent", (tester) async {
      final only = _agent(name: "aristotle-impl-review", description: "Reviews");
      for (final (agents, matcher) in [
        (const <AgentInfo>[], findsNothing),
        ([only], findsNothing),
        ([only, _agent(name: "other", description: "Other")], findsOneWidget),
      ]) {
        await tester.pumpWidget(_buildApp(agents: agents, onAgentSelected: (_) {}));
        expect(find.text("aristotle-impl-review"), matcher);
      }
    });

    testWidgets("shows every agent, with none clipped out of reach", (tester) async {
      await tester.pumpWidget(_buildApp(agents: _agents, onAgentSelected: (_) {}));

      await tester.tap(find.text("aristotle-impl-review"));
      await tester.pumpAndSettle();

      // Each agent is on screen, and the popup hides nothing below its fold —
      // the picker used to under-size itself around its subtitled rows, clipping
      // the last agent with no way to scroll to it.
      for (final agent in _agents) {
        expect(_menuItem(agent.name), findsOneWidget);
      }
      final popup = tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(popup.maxScrollExtent, equals(0.0));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets("selects the agent the tap landed on", (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(_buildApp(agents: _agents, onAgentSelected: selected.add));

      await tester.tap(find.text("aristotle-impl-review"));
      await tester.pumpAndSettle();

      // Aimed at the lower edge of a row, where the popup's tap arithmetic used
      // to have drifted far enough to select the agent below it.
      final row = _menuItem("plan");
      await tester.tapAt(tester.getRect(row).bottomCenter - const Offset(0, 4));
      await tester.pumpAndSettle();

      expect(selected, equals(["plan"]));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets("scrolls when a project brings more agents than fit", (tester) async {
      final agents = [
        for (var i = 0; i < 14; i++) _agent(name: "agent-$i", description: "Agent number $i."),
      ];
      await tester.pumpWidget(_buildApp(agents: agents, onAgentSelected: (_) {}));

      await tester.tap(find.text("aristotle-impl-review"));
      await tester.pumpAndSettle();

      // Past the cap the rows scroll rather than being cut off.
      final popup = tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(popup.maxScrollExtent, greaterThan(0.0));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  testWidgets("compact selectors size to their labels instead of sharing the strip", (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentModelButtons(
            surfaceStyle: PregoComposerSurfaceStyle.subtle,
            agents: [
              _agent(name: "build", description: "Build"),
              _agent(name: "plan", description: "Plan"),
            ],
            selectedAgent: "build",
            onAgentSelected: (_) {},
            providers: const [],
            selectedAgentModel: const AgentModel(providerID: "example", modelID: "m", variant: "high"),
            onModelSelected: ({required providerID, required modelID}) {},
            availableVariants: const [SessionVariant(id: "high")],
            onVariantSelected: (_) {},
            fastModeControl: FastModeControl.hidden,
            decideFastModeToggle: () => null,
            onFastModeChanged: (_) {},
            compact: true,
            trailing: const [],
          ),
        ),
      ),
    );

    double width(String label) =>
        tester.getSize(find.byWidgetPredicate((widget) => widget is PregoPickerButton && widget.label == label)).width;
    // A one-letter model is the narrowest chip, and none is stretched to the cap.
    expect(width("m"), lessThan(width("high")));
    expect(width("high"), lessThan(width("build")));
    expect(width("build"), lessThan(240));
  });

  for (final (width, chips, labels) in [(320.0, 2, false), (390.0, 0, true)]) {
    testWidgets("a touch row at $width points with $chips status chips fits (labels: $labels)", (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Widget square(String label) => PregoComposerChip(
        icon: TablerRegular.clock,
        label: label,
        showLabel: false,
        surfaceStyle: PregoComposerSurfaceStyle.subtle,
        onPressed: () {},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(
              // The composer's own inset on a phone.
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AgentModelButtons(
                surfaceStyle: PregoComposerSurfaceStyle.subtle,
                agents: [
                  _agent(name: "build", description: "Build"),
                  _agent(name: "plan", description: "Plan"),
                ],
                selectedAgent: "build",
                onAgentSelected: (_) {},
                providers: const [],
                selectedAgentModel: const AgentModel(providerID: "example", modelID: "sonnet", variant: "high"),
                onModelSelected: ({required providerID, required modelID}) {},
                availableVariants: const [SessionVariant(id: "high")],
                onVariantSelected: (_) {},
                fastModeControl: FastModeControl.off,
                decideFastModeToggle: () => null,
                onFastModeChanged: (_) {},
                compact: false,
                trailing: [square("YOLO"), square("Auto-continue")].take(chips).toList(),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(PregoPickerButton), findsNWidgets(3));
      // A crowded row keeps the pickers as glyphs; a roomy one keeps labels.
      expect(find.text("build"), labels ? findsOneWidget : findsNothing);
      expect(find.bySemanticsLabel("build"), findsOneWidget);
    });
  }
}
