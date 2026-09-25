import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "yolo_chip.dart";

/// The session's approval mode in its model row. YOLO shows the warning shield
/// and label; asking shows a quiet outline shield. Its menu picks the mode for
/// this session and marks the one the bridge setting gives by default.
class const SessionApprovalChip({
  super.key,
  required final PregoComposerSurfaceStyle surfaceStyle,
  required final SessionApprovalPerSession control,

  /// Touch rows show only the glyph, so the pickers keep their room.
  required final bool showLabel,
  required final bool updating,
  required final ValueChanged<SessionApprovalMode> onSelect,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final yolo = control.effective == SessionApprovalMode.yolo;
    return PregoAnchorMenu(
      flat: true,
      acquireOpenLease: null,
      menuMaxHeight: null,
      // Room for "Approve everything (YOLO) (default)" without truncation.
      menuWidth: 300,
      triggerBuilder: (context, toggle) => PregoComposerChip(
        key: const Key("session-approval-chip"),
        icon: yolo ? YoloChip.icon : TablerRegular.shield,
        label: yolo ? loc.sessionDetailYoloChip : loc.sessionApprovalAsk,
        // Asking is the quiet state: only its glyph, with the label as tooltip.
        showLabel: showLabel && yolo,
        isWarning: yolo,
        surfaceStyle: surfaceStyle,
        onPressed: toggle,
      ),
      entriesBuilder: () => [
        _item(
          context: context,
          key: const Key("session-approval-ask"),
          mode: SessionApprovalMode.ask,
          icon: TablerRegular.shield,
          title: loc.sessionApprovalAsk,
        ),
        _item(
          context: context,
          key: const Key("session-approval-yolo"),
          mode: SessionApprovalMode.yolo,
          icon: YoloChip.icon,
          title: loc.sessionApprovalYolo,
        ),
      ],
    );
  }

  PregoMenuItem _item({
    required BuildContext context,
    required Key key,
    required SessionApprovalMode mode,
    required IconData icon,
    required String title,
  }) => PregoMenuItem(
    key: key,
    leadingIcon: icon,
    title: mode == control.bridgeDefault ? context.loc.sessionApprovalDefaultOption(title) : title,
    subtitle: null,
    isSelected: mode == control.effective,
    isEnabled: !updating,
    isWarning: mode == SessionApprovalMode.yolo,
    shortcutLabel: null,
    onTap: () => onSelect(mode),
  );
}
