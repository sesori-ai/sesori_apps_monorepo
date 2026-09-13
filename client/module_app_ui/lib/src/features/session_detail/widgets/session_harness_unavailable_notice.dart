import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

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
      SessionInteractionBlockedReason.runtimeOutdated => loc.sessionDetailHarnessRuntimeOutdatedReason(harnessName),
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
    final prego = context.prego;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassContainer(
          useOwnLayer: true,
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(16),
          shape: const LiquidRoundedSuperellipse(borderRadius: 20),
          settings: LiquidGlassSettings(glassColor: prego.colors.bgSecondary.withValues(alpha: 0.7)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reason, style: prego.textTheme.textMd.bold),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(details, style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary)),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (blocked?.reason != SessionInteractionBlockedReason.contentLoadFailed)
                    PregoButtonsSolid(
                      key: const Key("session_harness_settings"),
                      label: loc.sessionDetailOpenHarnessSettings,
                      hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                      size: PregoButtonsSolidSize.sm,
                      onPressed: onOpenHarnessSettings,
                    ),
                  if (canRecheck)
                    TextButton(
                      key: const Key("session_harness_recheck"),
                      onPressed: onRecheck,
                      child: Text(loc.sessionDetailRecheck),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
