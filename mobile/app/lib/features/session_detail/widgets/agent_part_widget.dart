import "package:flutter/material.dart";

class AgentPartWidget extends StatelessWidget {
  final String? agentName;

  const AgentPartWidget({super.key, required this.agentName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = agentName ?? "Agent";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 14,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
