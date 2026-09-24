import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// Ongoing provider retry activity, distinct from a terminal error.
///
/// The shared motion primitives own animation and reduced-motion handling;
/// the backend's complete error text remains readable below the status row.
class const RetryErrorMessageCard({
  super.key,
  required final String message,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final label = context.loc.backgroundTaskStatusRetry;
    final style = prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              PregoAiLoader(fillMode: .outline, color: prego.colors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: PregoShimmer(
                  appearDelay: Duration.zero,
                  semanticLabel: label,
                  child: Text(label, style: style),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 24, top: 4),
            child: Text(message, style: style),
          ),
        ],
      ),
    );
  }
}
