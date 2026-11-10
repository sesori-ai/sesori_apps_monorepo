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

  /// Sets [request] as code under a pointer, as the review modal shows it.
  required final bool requestIsCode,

  /// Whether this card's action leads. With two cards, only the first one does.
  required final bool leads,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    const radius = PregoRadius.x2l;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, PregoSpacing.md),
      child: PregoPageHalo(
        radius: radius,
        reachesLayerBottom: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            // The light token reads cream; its dark twin is a heavy brown.
            color: isDark
                ? prego.colors.fgWarningPrimary.withValues(alpha: pointer ? 0.07 : 0.1)
                : prego.colors.bgWarningPrimary,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: prego.colors.fgWarningPrimary.withValues(alpha: pointer ? 0.24 : 0.3)),
          ),
          child: Padding(
            // Under a pointer the 8 pt button sits 8 pt into this 16 pt corner.
            padding: pointer
                ? const EdgeInsetsDirectional.fromSTEB(
                    PregoSpacing.lg,
                    PregoSpacing.md,
                    PregoSpacing.md,
                    PregoSpacing.md,
                  )
                : const EdgeInsetsDirectional.symmetric(horizontal: PregoSpacing.lg, vertical: PregoSpacing.lg),
            child: Row(
              spacing: PregoSpacing.lg,
              children: [
                Icon(icon, size: pointer ? 16 : PregoIconSize.md, color: prego.colors.fgWarningPrimary),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        // The light token is 3.3:1 on cream; one step darker clears 4.5:1.
                        style: prego.textTheme.textXs.medium.copyWith(
                          color: pointer
                              ? prego.colors.smallWarningText
                              : isDark
                              ? prego.colors.textWarningPrimary
                              : PregoColorPrimitives.warning700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        request,
                        style: (pointer && requestIsCode ? prego.textTheme.code : prego.textTheme.textSm.medium)
                            .copyWith(color: prego.colors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  // Stacked cards' actions share a left edge under a pointer.
                  constraints: BoxConstraints(minWidth: pointer ? 72 : 0),
                  child: PregoButtonsSolid(
                    label: action,
                    // A white pill in both themes; dark's grey secondary is lost on the tint.
                    hierarchy: switch ((isDark, pointer)) {
                      (_, true) when !leads => PregoButtonsSolidHierarchy.secondary,
                      (true, _) || (false, true) => PregoButtonsSolidHierarchy.primaryAlt,
                      (false, false) => PregoButtonsSolidHierarchy.secondary,
                    },
                    size: PregoButtonsSolidSize.sm,
                    onPressed: onPressed,
                  ),
                ),
              ],
            ),
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

/// Explains why the harness can no longer continue this session while its
/// stored history stays readable. [message] is the harness's own explanation,
/// shown as-is.
class const SessionDetailCannotContinueNotice({super.key, required final String message}) extends StatelessWidget {
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
          leading: Icon(TablerRegular.alert_triangle, size: PregoIconSize.md, color: prego.colors.textWarningPrimary),
          title: Text(context.loc.sessionDetailCannotContinueTitle),
          titleStyle: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary),
          subtitle: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
          subtitleStyle: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
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
