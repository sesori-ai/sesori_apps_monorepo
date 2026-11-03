import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";
import "../extensions/remote_failure_x.dart";

/// A load that failed, in the calm style of the other status pages: most
/// failures recover on their own once the connection is back, so it reads as
/// a status with a way to retry, not an alarm.
class const RemoteFailureView({
  required final RemoteFailureReason reason,
  required final String title,
  required final String retryLabel,
  required final VoidCallback onRetry,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(PregoSpacing.x2l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // An illustration, not a glyph: no icon token applies.
              Icon(
                reason == RemoteFailureReason.networkDown ? TablerRegular.cloud_off : TablerRegular.alert_circle,
                size: 48,
                color: prego.colors.textTertiary,
              ),
              const SizedBox(height: PregoSpacing.lg),
              Text(title, textAlign: TextAlign.center, style: prego.textTheme.textLg.bold),
              const SizedBox(height: PregoSpacing.xs),
              Text(
                reason.localizedMessage(context.loc),
                textAlign: TextAlign.center,
                style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
              ),
              const SizedBox(height: PregoSpacing.xl),
              PregoButtonsSolid(
                label: retryLabel,
                leadingIcon: TablerRegular.refresh,
                hierarchy: PregoButtonsSolidHierarchy.secondary,
                size: PregoButtonsSolidSize.md,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
