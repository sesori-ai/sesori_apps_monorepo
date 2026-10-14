import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";

/// Switches the app to another computer, reporting where the switch started.
typedef ComputerSwitchCallback = void Function({required String bridgeId, required ComputerSwitchSource source});

/// The account's computers, anchored to the trigger [triggerBuilder] builds.
///
/// Each row shows the computer's platform, name, and whether its bridge is
/// online, with a check on the one the app is pointed at. Picking another
/// computer calls [onSelect]; picking the current one only closes the menu.
/// Reads [ComputerSwitcherCubit], which the product shell provides.
class const ComputerMenu({
  super.key,
  required final PregoMenuTriggerBuilder triggerBuilder,
  required final void Function({required String bridgeId}) onSelect,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ComputerSwitcherCubit>().state;
    final currentId = state.currentId;
    return PregoAnchorMenu(
      // The trigger is a flat text row, which a glass popup would not match.
      flat: true,
      acquireOpenLease: null,
      menuWidth: 280,
      triggerBuilder: triggerBuilder,
      entriesBuilder: () => [
        for (final computer in state.computers)
          PregoMenuItem(
            key: ValueKey("computer-menu-${computer.id}"),
            title: computer.name,
            subtitle: presenceLabel(context: context, computer: computer),
            leadingIcon: platformIcon(platform: computer.platform),
            isSelected: computer.id == currentId,
            shortcutLabel: null,
            onTap: () {
              if (computer.id != currentId) onSelect(bridgeId: computer.id);
            },
          ),
      ],
    );
  }

  /// "Online", or "Offline" with the last-seen time when one is known.
  static String presenceLabel({required BuildContext context, required BridgeSummary computer}) {
    final loc = context.loc;
    if (computer.status == BridgeRegistrationStatus.active) return loc.computerMenuOnline;
    final lastSeenAt = computer.lastSeenAt;
    if (lastSeenAt == null) return loc.computerMenuOffline;
    return loc.computerMenuOfflineLastSeen(context.formatTimestamp(lastSeenAt.millisecondsSinceEpoch));
  }

  /// The glyph every computer list shows for a computer's operating system.
  static IconData platformIcon({required BridgePlatform platform}) => switch (platform) {
    BridgePlatform.macos => TablerRegular.brand_apple,
    BridgePlatform.windows => TablerRegular.brand_windows,
    BridgePlatform.linux => TablerRegular.terminal_2,
    BridgePlatform.unknown => TablerRegular.device_desktop,
  };
}
