import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";
import "../features/settings/widgets/settings_section.dart";
import "computer_menu.dart";

/// How many online computers the card lists before folding the rest into a
/// row that opens the computer menu.
const int _listedLimit = 2;

/// The bridge-offline screen's way out: the account's other computers that are
/// online, each a one-tap switch.
///
/// Lists up to two online computers, most recently seen first; when more are
/// online, a "+ n others" row opens the [ComputerMenu] with every computer.
/// With other computers but none online it says so. An account with only the
/// offline computer has nothing to offer, so the card takes no space then; it
/// grows into place once the list arrives instead of pushing the page down in
/// one frame. Reads [ComputerSwitcherCubit], which the product shell provides,
/// and reports every switch as started on the offline screen.
class const OtherComputersCard({
  super.key,
  required final ComputerSwitchCallback onSwitchComputer,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ComputerSwitcherCubit>().state;
    final others = state.computers.where((computer) => computer.id != state.currentId).toList();
    final card = others.isEmpty
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsetsDirectional.only(top: PregoSpacing.x3l),
            child: SettingsSection(
              title: context.loc.projectsBridgeOfflineOtherComputers,
              child: PregoGroupedRows(
                children: _rows(context: context, others: others),
              ),
            ),
          );
    // Under reduced motion no wrapper at all: a zero-length AnimatedSize would
    // re-dirty itself mid-layout.
    if (context.isReducedMotion) return card;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: card,
    );
  }

  List<Widget> _rows({required BuildContext context, required List<BridgeSummary> others}) {
    final online = others.where((computer) => computer.status == BridgeRegistrationStatus.active).toList();
    if (online.isEmpty) {
      return [
        PregoGroupedRow(
          title: Text(
            context.loc.projectsBridgeOfflineNoOtherComputersOnline,
            style: TextStyle(color: context.prego.colors.textTertiary),
          ),
        ),
      ];
    }
    final unlisted = online.length - _listedLimit;
    return [
      for (final computer in online.take(_listedLimit))
        PregoGroupedRow(
          key: ValueKey("other-computer-${computer.id}"),
          icon: ComputerMenu.platformIcon(platform: computer.platform),
          title: Text(computer.name),
          trailing: const Icon(TablerRegular.chevron_right),
          onTap: () => _switch(bridgeId: computer.id),
        ),
      if (unlisted > 0)
        ComputerMenu(
          key: const ValueKey("other-computers-more"),
          onSelect: _switch,
          // The card leads back to a working computer, not to management.
          onManageComputers: null,
          currentFirst: false,
          triggerBuilder: (context, toggle) => PregoGroupedRow(
            title: Text(context.loc.projectsBridgeOfflineMoreComputers(unlisted)),
            trailing: const Icon(TablerRegular.chevron_down),
            onTap: toggle,
          ),
        ),
    ];
  }

  void _switch({required String bridgeId}) =>
      onSwitchComputer(bridgeId: bridgeId, source: ComputerSwitchSource.offlineScreen);
}
