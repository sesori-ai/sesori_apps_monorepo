import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";

/// The bridge-offline screen's heading: "dev-laptop is offline", or the generic
/// "Bridge offline" while [bridge] is unknown, then when it was last seen.
class const ComputerOfflineHeading({
  super.key,

  /// Null while the account's list has not named the computer, or the lookup
  /// failed; the last-seen line is hidden then.
  required final BridgeSummary? bridge,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final bridge = this.bridge;
    final lastSeenAt = bridge?.lastSeenAt;
    final title = bridge == null ? loc.projectsBridgeOfflineTitle : loc.projectsBridgeOfflineComputerTitle(bridge.name);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cross-fades when the lookup lands and the generic heading gives way
        // to the computer's name.
        AnimatedSwitcher(
          duration: context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 220),
          child: Text(
            title,
            key: ValueKey(title),
            textAlign: TextAlign.center,
            style: prego.textTheme.textMd.medium.copyWith(color: prego.colors.textPrimary),
          ),
        ),
        // How long the bridge has been gone separates "I just closed the
        // laptop lid" from "this has been down for days".
        if (lastSeenAt != null) ...[
          const SizedBox(height: PregoSpacing.xxs),
          Text(
            loc.projectsBridgeOfflineLastSeen(context.formatTimestamp(lastSeenAt.millisecondsSinceEpoch)),
            textAlign: TextAlign.center,
            style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
          ),
        ],
      ],
    );
  }
}
