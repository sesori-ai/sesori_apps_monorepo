import "package:flutter/material.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../../core/extensions/build_context_x.dart";

class AgentPartWidget extends StatelessWidget {
  final String? agentName;

  const AgentPartWidget({super.key, required this.agentName});

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final loc = context.loc;
    final label = agentName ?? loc.sessionDetailAgentFallback;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 14,
            color: zyra.colors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: zyra.textTheme.textXs.medium.copyWith(
              color: zyra.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
