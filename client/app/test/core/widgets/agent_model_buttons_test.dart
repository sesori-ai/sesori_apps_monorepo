import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
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
          ),
          // The prompt field sits below the picker row in the chat composer.
          const SizedBox(height: 120),
        ],
      ),
    ),
  );
}

void main() {
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
      expect(find.descendant(of: _menuItem("minimal"), matching: find.byIcon(Icons.check)), findsOneWidget);

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
}
