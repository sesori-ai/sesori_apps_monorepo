import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:sesori_mobile/core/widgets/agent_model_buttons.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

/// The agents a real project reports — a handful, each with a description long
/// enough to run past the row and ellipsize.
final _agents = [
  _agent(name: "build", description: "The default agent. Executes tools and edits files."),
  _agent(name: "plan", description: "Plan mode. Disallows all edit tools."),
  _agent(name: "sesori-plan-maker", description: "Creates implementation-ready, reviewed plans."),
  _agent(name: "sesori-plan-worker", description: "Executes one reviewed plan step end to end."),
];

AgentInfo _agent({required String name, required String description}) =>
    AgentInfo(name: name, description: description, model: null, mode: AgentMode.all);

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
            agents: agents,
            selectedAgent: "sesori-plan-worker",
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

void main() {
  group("Agent picker", () {
    testWidgets("shows every agent, with none clipped out of reach", (tester) async {
      await tester.pumpWidget(_buildApp(agents: _agents, onAgentSelected: (_) {}));

      await tester.tap(find.text("sesori-plan-worker"));
      await tester.pumpAndSettle();

      // Each agent is on screen, and the popup hides nothing below its fold —
      // the picker used to under-size itself around its subtitled rows, clipping
      // the last agent with no way to scroll to it.
      for (final agent in _agents) {
        expect(find.widgetWithText(GlassMenuItem, agent.name), findsOneWidget);
      }
      final popup = tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(popup.maxScrollExtent, equals(0.0));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets("selects the agent the tap landed on", (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(_buildApp(agents: _agents, onAgentSelected: selected.add));

      await tester.tap(find.text("sesori-plan-worker"));
      await tester.pumpAndSettle();

      // Aimed at the lower edge of a row, where the popup's tap arithmetic used
      // to have drifted far enough to select the agent below it.
      final row = find.widgetWithText(GlassMenuItem, "plan");
      await tester.tapAt(tester.getRect(row).bottomCenter - const Offset(0, 4));
      await tester.pumpAndSettle();

      expect(selected, equals(["plan"]));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets("scrolls when a project brings more agents than fit", (tester) async {
      final agents = [
        for (var i = 0; i < 14; i++) _agent(name: "agent-$i", description: "Agent number $i."),
      ];
      await tester.pumpWidget(_buildApp(agents: agents, onAgentSelected: (_) {}));

      await tester.tap(find.text("sesori-plan-worker"));
      await tester.pumpAndSettle();

      // Past the cap the rows scroll rather than being cut off.
      final popup = tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(popup.maxScrollExtent, greaterThan(0.0));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
