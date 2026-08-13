import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";

class const RetryPartWidget({
  super.key,
  required final int? attempt,
  required final String? retryError,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final label = StringBuffer(loc.sessionDetailRetryLabel);
    if (attempt != null) {
      label.write(" #$attempt");
    }
    if (retryError != null) {
      label.write(": $retryError");
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.refresh,
            size: 14,
            color: prego.colors.fgSuccessPrimary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label.toString(),
              style: prego.textTheme.textXs.medium.copyWith(
                color: prego.colors.fgSuccessPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
