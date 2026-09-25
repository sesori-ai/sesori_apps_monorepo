import "dart:async";

import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// Neutral "⚡ YOLO" chip in the session's model row while the connected
/// bridge approves every permission request. A tap explains YOLO and offers
/// the settings where it is turned off.
class const YoloChip({
  super.key,
  required final PregoComposerSurfaceStyle surfaceStyle,
  required final VoidCallback onOpenSettings,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final foreground = prego.colors.textSecondary;
    final borderRadius = BorderRadius.circular(PregoRadius.full);
    return Semantics(
      button: true,
      child: SizedBox(
        height: 36,
        child: DecoratedBox(
          decoration: pregoComposerSurfaceDecoration(prego: prego, style: surfaceStyle, borderRadius: borderRadius),
          child: Padding(
            padding: const EdgeInsets.all(1),
            child: Material(
              color: Colors.transparent,
              borderRadius: borderRadius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                mouseCursor: WidgetStateMouseCursor.clickable,
                onTap: () => unawaited(_explain(context)),
                borderRadius: borderRadius,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      Icon(TablerRegular.bolt, size: PregoIconSize.sm, color: foreground),
                      Text(
                        context.loc.sessionDetailYoloChip,
                        style: prego.textTheme.textXs.medium.copyWith(color: foreground),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _explain(BuildContext context) async {
    final loc = context.loc;
    final prego = context.prego;
    final openSettings = await showPregoModal<bool>(
      context: context,
      title: loc.sessionDetailYoloTitle,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loc.settingsYoloDescription,
              style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
            ),
            const SizedBox(height: PregoSpacing.x2l),
            PregoButtonsSolid(
              key: const Key("yolo_open_settings"),
              label: loc.sessionDetailYoloOpenSettings,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.xl,
              fullWidth: true,
              onPressed: () => sheetContext.pop(true),
            ),
          ],
        ),
      ),
    );
    if (openSettings ?? false) onOpenSettings();
  }
}
