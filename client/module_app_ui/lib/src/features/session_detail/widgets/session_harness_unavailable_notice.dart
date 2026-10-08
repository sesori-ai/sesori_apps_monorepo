import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../../extensions/build_context_x.dart";
import "../../../widgets/bridge_update_sheet.dart";
import "../../../widgets/harness_blocked_notice.dart";

class const SessionHarnessUnavailableNotice({
  super.key,
  required final SessionInteractionState interaction,
  required final bool historyUnavailable,
  required final VoidCallback onOpenHarnessSettings,
  required final VoidCallback onRecheck,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final current = interaction;
    final blocked = current is SessionInteractionBlocked ? current : null;
    final harnessName = blocked?.displayName ?? loc.sessionDetailHarnessFallbackName;
    final reason = switch (blocked?.reason) {
      SessionInteractionBlockedReason.disabled => loc.sessionDetailHarnessDisabledReason(harnessName),
      SessionInteractionBlockedReason.authenticationRequired => loc.sessionDetailHarnessAuthenticationReason(
        harnessName,
      ),
      SessionInteractionBlockedReason.runtimeMissing => loc.sessionDetailHarnessRuntimeMissingReason(harnessName),
      SessionInteractionBlockedReason.stopping => loc.sessionDetailHarnessStoppingReason(harnessName),
      SessionInteractionBlockedReason.notInspected => loc.sessionDetailHarnessNotInspectedReason(harnessName),
      SessionInteractionBlockedReason.unknownStatus => loc.sessionDetailHarnessUnknownReason(harnessName),
      SessionInteractionBlockedReason.missingHarness => loc.sessionDetailHarnessMissingReason,
      SessionInteractionBlockedReason.statusCheckFailed => loc.sessionDetailHarnessCheckFailedReason,
      SessionInteractionBlockedReason.contentLoadFailed => loc.sessionDetailContentLoadFailedReason,
      SessionInteractionBlockedReason.unavailable => loc.sessionDetailHarnessUnavailableReason(harnessName),
      null => switch (interaction) {
        SessionInteractionLegacyUnverified() => loc.sessionDetailHarnessLegacyWarning,
        SessionInteractionAvailable() => loc.sessionDetailHarnessRefreshWarning,
        SessionInteractionChecking() || SessionInteractionBlocked() => loc.sessionDetailHarnessCheckingReason,
      },
    };
    final details = [
      if (blocked?.actionHint case final hint? when hint.trim().isNotEmpty) hint,
      if (historyUnavailable) loc.sessionDetailHarnessHistoryUnavailable,
      if (blocked?.refreshError != null && blocked?.reason != SessionInteractionBlockedReason.statusCheckFailed)
        loc.sessionDetailHarnessRefreshWarning,
    ].join("\n");
    final canRecheck = blocked?.reason == SessionInteractionBlockedReason.authenticationRequired;

    // An old bridge is fixed on the computer running it, which harness
    // settings cannot do, so it offers the update steps instead.
    final bridgeOutdated = interaction is SessionInteractionLegacyUnverified;

    return HarnessBlockedNotice(
      title: reason,
      details: details,
      onOpenHarnessSettings: bridgeOutdated || blocked?.reason == SessionInteractionBlockedReason.contentLoadFailed
          ? null
          : onOpenHarnessSettings,
      onShowBridgeUpdate: bridgeOutdated ? () => showBridgeUpdateSheet(context: context) : null,
      onRecheck: canRecheck ? onRecheck : null,
    );
  }
}
