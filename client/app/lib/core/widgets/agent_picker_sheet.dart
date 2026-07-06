import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";

/// Bottom sheet for selecting an agent.
///
/// Simple list of available agents with the current selection highlighted.
/// Tapping an agent selects it and closes the sheet.
class AgentPickerSheet extends StatelessWidget {
  final List<AgentInfo> agents;
  final String selectedAgent;
  final ValueChanged<String> onAgentChanged;

  const AgentPickerSheet({
    super.key,
    required this.agents,
    required this.selectedAgent,
    required this.onAgentChanged,
  });

  /// Shows the agent picker as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required List<AgentInfo> agents,
    required String selectedAgent,
    required ValueChanged<String> onAgentChanged,
  }) {
    return showPregoBottomSheet<void>(
      context: context,
      title: context.loc.sessionDetailPickerAgent,
      // Full-bleed tiles; each ListTile carries its own horizontal padding.
      contentPadding: EdgeInsetsDirectional.zero,
      builder: (_) => AgentPickerSheet(
        agents: agents,
        selectedAgent: selectedAgent,
        onAgentChanged: (agent) {
          onAgentChanged(agent);
          context.pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    // Transparent Material so the tiles' ink paints on top of the sheet
    // surface instead of behind it on the modal's transparent Material.
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: .min,
        children: [
          for (final agent in agents)
            ListTile(
              dense: true,
              title: Text(agent.name),
              subtitle: switch (agent.description) {
                final description? => Text(description, maxLines: 1, overflow: .ellipsis),
                null => null,
              },
              leading: agent.name == selectedAgent
                  ? Icon(Icons.radio_button_checked, color: prego.colors.bgBrandSolid)
                  : Icon(Icons.radio_button_unchecked, color: prego.colors.borderPrimary),
              onTap: () => onAgentChanged(agent.name),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
