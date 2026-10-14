import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../widgets/computer_menu.dart";

/// Gap between the computer entry and the settings that apply to it.
const double _entryGap = PregoSpacing.lg;

/// The computer the bridge settings below it apply to, in a card of its own:
/// platform, name, and whether it is online. Tapping it opens the computer
/// menu; picking another computer switches with the Settings source.
///
/// Renders nothing until the account's list names the current computer, and
/// grows into place when it does instead of pushing the settings down at once.
class const ComputerSettingsEntry({
  super.key,
  required final ComputerSwitchCallback onSwitchComputer,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ComputerSwitcherCubit>().state;
    final currentId = state.currentId;
    final computer = state.computers.where((computer) => computer.id == currentId).firstOrNull;
    return AnimatedSize(
      duration: context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: AlignmentDirectional.topStart,
      child: computer == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsetsDirectional.only(bottom: _entryGap),
              child: ComputerMenu(
                onSelect: ({required bridgeId}) =>
                    onSwitchComputer(bridgeId: bridgeId, source: ComputerSwitchSource.settings),
                triggerBuilder: (context, toggle) => PregoGroupedRows(
                  children: [
                    Semantics(
                      hint: context.loc.computerMenuSwitchHint,
                      child: PregoGroupedRow(
                        key: const Key("computer_settings_entry"),
                        leading: PregoAvatarUser(icon: ComputerMenu.platformIcon(platform: computer.platform)),
                        leadingWidth: 40,
                        title: Text(computer.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(ComputerMenu.presenceLabel(context: context, computer: computer)),
                        trailing: const Icon(TablerRegular.selector),
                        onTap: toggle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
