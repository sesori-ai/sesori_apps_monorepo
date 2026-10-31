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
/// online, led by a green or red dot, with a check on the one the app is
/// pointed at. Picking another computer calls [onSelect]; picking the current
/// one only closes the menu. Reads [ComputerSwitcherCubit], which the product
/// shell provides.
class const ComputerMenu({
  super.key,
  required final PregoMenuTriggerBuilder triggerBuilder,
  required final void Function({required String bridgeId}) onSelect,

  /// Opens the Computers page from a "Manage computers…" item below the
  /// computers, or null where the menu offers no way there.
  required final VoidCallback? onManageComputers,

  /// Lists the current computer first, for a trigger that does not name it;
  /// otherwise the computers keep the account's order.
  required final bool currentFirst,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ComputerSwitcherCubit>().state;
    return PregoAnchorMenu(
      // Flat whatever the trigger, so the menu looks the same from a text row
      // and from the phone home's glass button.
      flat: true,
      acquireOpenLease: null,
      menuWidth: 280,
      triggerBuilder: triggerBuilder,
      entriesBuilder: () => entries(
        context: context,
        state: state,
        onSelect: onSelect,
        onManageComputers: onManageComputers,
        currentFirst: currentFirst,
      ),
    );
  }

  /// The menu's rows, for a menu that shows them above rows of its own.
  static List<PregoMenuEntry> entries({
    required BuildContext context,
    required ComputerSwitcherState state,
    required void Function({required String bridgeId}) onSelect,
    required VoidCallback? onManageComputers,
    required bool currentFirst,
  }) {
    final currentId = state.currentId;
    return [
      for (final computer in [
        if (currentFirst) ...state.computers.where((computer) => computer.id == currentId),
        ...state.computers.where((computer) => !currentFirst || computer.id != currentId),
      ])
        PregoMenuStatusItem(
          key: ValueKey("computer-menu-${computer.id}"),
          title: state.isThisComputer(bridgeId: computer.id) ? context.loc.desktopSettingsThisComputer : computer.name,
          status: presenceStatus(computer: computer),
          statusText: presenceLabel(context: context, computer: computer),
          leadingIcon: platformIcon(platform: computer.platform),
          isSelected: computer.id == currentId,
          onTap: () {
            if (computer.id != currentId) onSelect(bridgeId: computer.id);
          },
        ),
      if (onManageComputers != null) ...[
        const PregoMenuDivider(),
        PregoMenuItem(
          key: const ValueKey("computer-menu-manage"),
          title: context.loc.computerMenuManage,
          subtitle: null,
          leadingIcon: TablerRegular.settings,
          isSelected: false,
          shortcutLabel: null,
          onTap: onManageComputers,
        ),
      ],
    ];
  }

  /// "Online", or "Offline" with the last-seen time when one is known.
  static String presenceLabel({required BuildContext context, required BridgeSummary computer}) {
    final loc = context.loc;
    if (computer.status == BridgeRegistrationStatus.active) return loc.computerMenuOnline;
    final lastSeenAt = computer.lastSeenAt;
    if (lastSeenAt == null) return loc.computerMenuOffline;
    return loc.computerMenuOfflineLastSeen(context.formatTimestamp(lastSeenAt.millisecondsSinceEpoch));
  }

  /// The dot before [presenceLabel]: green while the computer's bridge is
  /// registered as active, red otherwise. Like the words, it follows the
  /// registration, not the live connection the home's computer button shows.
  static PregoNavStatus presenceStatus({required BridgeSummary computer}) =>
      computer.status == BridgeRegistrationStatus.active ? PregoNavStatus.online : PregoNavStatus.error;

  /// The glyph every computer list shows for a computer's operating system.
  static IconData platformIcon({required BridgePlatform platform}) => switch (platform) {
    BridgePlatform.macos => TablerRegular.brand_apple,
    BridgePlatform.windows => TablerRegular.brand_windows,
    BridgePlatform.linux => TablerRegular.terminal_2,
    BridgePlatform.unknown => TablerRegular.device_desktop,
  };
}
