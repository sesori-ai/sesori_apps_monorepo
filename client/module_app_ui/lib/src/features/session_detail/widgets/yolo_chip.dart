import "dart:async";

import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// "YOLO" chip in the session's model row while a bridge that cannot choose
/// per session approves every permission request. A tap explains YOLO and
/// offers the settings where it is turned off.
class const YoloChip({
  super.key,
  required final PregoComposerSurfaceStyle surfaceStyle,

  /// Touch rows show only the glyph, so the pickers keep their room.
  required final bool showLabel,
  required final VoidCallback onOpenSettings,
}) extends StatelessWidget {
  /// The one icon that stands for YOLO wherever it appears: Tabler's
  /// `shield-exclamation`, in the spirit of Codex's "Full access". Fast mode
  /// keeps the bolt. Declared by hand because the icon generator skips
  /// codepoints above U+F8FF, so `TablerRegular` has no constant for it.
  static const IconData icon = IconData(0xF9C6, fontFamily: "TablerRegular", fontPackage: "theme_prego");

  @override
  Widget build(BuildContext context) => PregoComposerChip(
    icon: icon,
    label: context.loc.sessionDetailYoloChip,
    showLabel: showLabel,
    isWarning: true,
    surfaceStyle: surfaceStyle,
    onPressed: () => unawaited(_explain(context)),
  );

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
