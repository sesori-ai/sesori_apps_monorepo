import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart"
    show FastModeToggleApply, FastModeToggleConfirmCacheReset, FastModeToggleDecision, FastModeToggleUnavailable;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// Answers a tap on a fast-mode control: switches right away, explains why the
/// account cannot use fast mode, or asks first when the switch would drop a
/// warm prompt cache. [decide] is read at tap time.
Future<void> toggleFastMode({
  required BuildContext context,
  required FastModeToggleDecision? Function() decide,
  required ValueChanged<bool> onFastModeChanged,
}) async {
  switch (decide()) {
    case null:
      return;
    case FastModeToggleApply(:final fastMode):
      onFastModeChanged(fastMode);
    case FastModeToggleUnavailable(:final reason):
      final loc = context.loc;
      PregoPopupAlertPresenter.of(context).show(
        title: loc.sessionDetailFastModeUnavailableTitle,
        variant: PregoPopupAlertsNotificationsVariant.error,
        content: PregoPopupAlertContent(
          message: switch (reason) {
            FastModeUnavailableReason.extraUsageDisabled => loc.sessionDetailFastModeUnavailableExtraUsageDisabled,
            FastModeUnavailableReason.notOnPlan => loc.sessionDetailFastModeUnavailableNotOnPlan,
            FastModeUnavailableReason.disabledByOrganization =>
              loc.sessionDetailFastModeUnavailableDisabledByOrganization,
            FastModeUnavailableReason.unknown => loc.sessionDetailFastModeUnavailableUnknown,
          },
        ),
      );
    case FastModeToggleConfirmCacheReset(:final fastMode):
      final confirmed = await _showFastModeConfirmation(context: context, fastMode: fastMode);
      if (confirmed ?? false) onFastModeChanged(fastMode);
  }
}

Future<bool?> _showFastModeConfirmation({required BuildContext context, required bool fastMode}) {
  final loc = context.loc;
  final prego = context.prego;
  return showPregoModal<bool>(
    context: context,
    title: loc.sessionDetailFastModeConfirmTitle,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            fastMode ? loc.sessionDetailFastModeConfirmEnableBody : loc.sessionDetailFastModeConfirmDisableBody,
            style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
          ),
          const SizedBox(height: PregoSpacing.x2l),
          PregoButtonsSolid(
            key: const Key("fast_mode_confirm"),
            label: loc.sessionDetailFastModeConfirmAction,
            hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
            size: PregoButtonsSolidSize.xl,
            fullWidth: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: PregoSpacing.md),
          PregoButtonsSolid(
            key: const Key("fast_mode_cancel"),
            label: loc.sessionDetailFastModeCancel,
            hierarchy: PregoButtonsSolidHierarchy.tertiary,
            size: PregoButtonsSolidSize.xl,
            fullWidth: true,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    ),
  );
}
