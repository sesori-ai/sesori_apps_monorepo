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

  /// Has the bridge inspect the harness setup again, the way harness settings'
  /// Check setup does.
  required final Future<void> Function() onCheckSetup,
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
    // A block recorded by setup inspection clears only when setup is inspected
    // again, even once the user has fixed it outside Sesori.
    final canCheckSetup = switch (blocked?.reason) {
      SessionInteractionBlockedReason.authenticationRequired || SessionInteractionBlockedReason.unavailable => true,
      SessionInteractionBlockedReason.disabled ||
      SessionInteractionBlockedReason.runtimeMissing ||
      SessionInteractionBlockedReason.stopping ||
      SessionInteractionBlockedReason.notInspected ||
      SessionInteractionBlockedReason.unknownStatus ||
      SessionInteractionBlockedReason.missingHarness ||
      SessionInteractionBlockedReason.statusCheckFailed ||
      SessionInteractionBlockedReason.contentLoadFailed ||
      null => false,
    };

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
      recheck: canCheckSetup ? (label: loc.harnessManagementRefreshSetup, onPressed: onCheckSetup) : null,
    );
  }
}
