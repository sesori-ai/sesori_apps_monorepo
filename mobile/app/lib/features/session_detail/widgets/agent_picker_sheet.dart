import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/app_modal_bottom_sheet.dart";

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
    return showAppModalBottomSheet(
      context: context,
      builder: (_) => AgentPickerSheet(
        agents: agents,
        selectedAgent: selectedAgent,
        onAgentChanged: (agent) {
          onAgentChanged(agent);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;

    return Column(
      mainAxisSize: .min,
      children: [
        // Drag handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            loc.sessionDetailPickerAgent,
            style: theme.textTheme.titleMedium,
          ),
        ),
        for (final agent in agents)
          ListTile(
            dense: true,
            title: Text(agent.name),
            subtitle: agent.description != null ? Text(agent.description!, maxLines: 1, overflow: .ellipsis) : null,
            leading: agent.name == selectedAgent
                ? Icon(Icons.radio_button_checked, color: theme.colorScheme.primary)
                : Icon(Icons.radio_button_unchecked, color: theme.colorScheme.outline),
            onTap: () => onAgentChanged(agent.name),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
