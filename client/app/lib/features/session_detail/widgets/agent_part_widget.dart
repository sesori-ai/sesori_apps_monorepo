import "package:flutter/material.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";

class AgentPartWidget extends StatelessWidget {
  final String? agentName;

  const AgentPartWidget({super.key, required this.agentName});

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final label = agentName ?? loc.sessionDetailAgentFallback;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 14,
            color: prego.colors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: prego.textTheme.textXs.medium.copyWith(
              color: prego.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
