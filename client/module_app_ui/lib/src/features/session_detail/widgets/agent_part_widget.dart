import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

class const AgentPartWidget({super.key, required final String agentName}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final label = agentName.isEmpty ? loc.sessionDetailAgentFallback : agentName;

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
