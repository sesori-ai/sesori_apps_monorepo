import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "transcript_live_row.dart";

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
              const TranscriptLiveSparkle(),
              const SizedBox(width: 4),
              Expanded(
                child: TranscriptLiveLabel(
                  label: Text(label, style: style),
                  semanticLabel: label,
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
