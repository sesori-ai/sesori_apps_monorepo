import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";
import "package:theme_prego/theme/primitives/prego_color_primitives.g.dart";

import "../../../extensions/build_context_x.dart";
import "../../../widgets/remote_failure_view.dart";

/// A pale amber card docked above the composer while the session waits on
/// the user for a question or permission: amber means it needs you. It names
/// what is pending, shows the first request's opening line, and its button
/// opens the existing modal.
class const SessionDetailNeedsYouCard({
  super.key,
  required final IconData icon,
  required final String label,
  required final String request,
  required final String action,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, PregoSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // The light token reads cream; its dark twin is a heavy brown.
          color: isDark ? prego.colors.fgWarningPrimary.withValues(alpha: 0.1) : prego.colors.bgWarningPrimary,
          borderRadius: BorderRadius.circular(PregoRadius.x2l),
          border: Border.all(color: prego.colors.fgWarningPrimary.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(PregoSpacing.lg),
          child: Row(
            spacing: PregoSpacing.lg,
            children: [
              Icon(icon, size: PregoIconSize.md, color: prego.colors.fgWarningPrimary),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      // The light token is 3.3:1 on cream; one step darker clears 4.5:1.
                      style: prego.textTheme.textXs.medium.copyWith(
                        color: isDark ? prego.colors.textWarningPrimary : PregoColorPrimitives.warning700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      request,
                      style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PregoButtonsSolid(
                label: action,
                // A white pill in both themes; dark's grey secondary is lost on the tint.
                hierarchy: isDark ? PregoButtonsSolidHierarchy.primaryAlt : PregoButtonsSolidHierarchy.secondary,
                size: PregoButtonsSolidSize.sm,
                onPressed: onPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explains why an archived session shows no composer: archiving is permanent,
/// so the session is readable but can never be prompted or reopened again.
class const SessionDetailArchivedNotice({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
      child: GlassContainer(
        useOwnLayer: true,
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.zero,
        shape: const LiquidRoundedSuperellipse(borderRadius: 20),
        settings: LiquidGlassSettings(glassColor: prego.colors.bgSecondary.withValues(alpha: 0.6)),
        child: GlassListTile(
          leading: Icon(TablerRegular.archive, size: PregoIconSize.md, color: prego.colors.textSecondary),
          title: Text(context.loc.sessionDetailArchivedNotice),
          titleStyle: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
        ),
      ),
    );
  }
}

class const SessionDetailErrorView({
  super.key,
  required final RemoteFailureReason reason,
  required final VoidCallback onRetry,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return RemoteFailureView(
      reason: reason,
      title: loc.sessionDetailErrorTitle,
      retryLabel: loc.sessionDetailRetry,
      onRetry: onRetry,
    );
  }
}
