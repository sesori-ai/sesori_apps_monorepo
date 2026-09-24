import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";

/// Stands in for a composer that cannot send: why, what to do about it, and
/// the way to harness settings and a recheck when either applies.
class const HarnessBlockedNotice({
  super.key,
  required final String title,
  required final String? details,
  required final VoidCallback? onOpenHarnessSettings,
  required final VoidCallback? onRecheck,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final details = this.details;
    final onOpenHarnessSettings = this.onOpenHarnessSettings;
    final onRecheck = this.onRecheck;

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
              Text(title, style: prego.textTheme.textMd.bold),
              if (details != null && details.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(details, style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary)),
              ],
              if (onOpenHarnessSettings != null || onRecheck != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (onOpenHarnessSettings != null)
                      PregoButtonsSolid(
                        key: const Key("session_harness_settings"),
                        label: loc.sessionDetailOpenHarnessSettings,
                        hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                        size: PregoButtonsSolidSize.sm,
                        onPressed: onOpenHarnessSettings,
                      ),
                    if (onRecheck != null)
                      TextButton(
                        key: const Key("session_harness_recheck"),
                        onPressed: onRecheck,
                        child: Text(loc.sessionDetailRecheck),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
