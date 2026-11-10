import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../widgets/computer_menu.dart";

/// The computer the bridge settings below it apply to, in a card of its own:
/// platform, name, and whether it is online. Tapping it opens the computer
/// menu; picking another computer switches with the Settings source, and the
/// menu's footer opens the Computers page.
///
/// Renders nothing, card included, until the account's list names the current
/// computer, and grows into place when it does instead of pushing the settings
/// down at once.
class const ComputerSettingsEntry({
  super.key,
  required final ComputerSwitchCallback onSwitchComputer,
  required final VoidCallback onManageComputers,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ComputerSwitcherCubit>().state;
    final currentId = state.currentId;
    final computer = state.computers.where((computer) => computer.id == currentId).firstOrNull;
    final prego = context.prego;
    final entry = computer == null
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.md),
            child: PregoGroupedRows(
              children: [
                ComputerMenu(
                  onSelect: ({required bridgeId}) =>
                      onSwitchComputer(bridgeId: bridgeId, source: ComputerSwitchSource.settings),
                  onManageComputers: onManageComputers,
                  currentFirst: false,
                  triggerBuilder: (context, toggle) => Semantics(
                    hint: context.loc.computerMenuSwitchHint,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        key: const Key("computer_settings_entry"),
                        mouseCursor: WidgetStateMouseCursor.clickable,
                        onTap: toggle,
                        child: Padding(
                          // On the card rows' icon and trailing columns, inside the ink so the
                          // whole card opens the menu.
                          padding: const EdgeInsetsDirectional.fromSTEB(18, PregoSpacing.sm, 12, PregoSpacing.sm),
                          child: Row(
                            spacing: PregoSpacing.md,
                            children: [
                              Icon(
                                ComputerMenu.platformIcon(platform: computer.platform),
                                size: PregoIconSize.lg,
                                color: prego.colors.textTertiary,
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      computer.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: prego.textTheme.textMd.regular.copyWith(
                                        color: prego.colors.textPrimary,
                                      ),
                                    ),
                                    PregoStatusLabel(
                                      status: ComputerMenu.presenceStatus(computer: computer),
                                      text: ComputerMenu.presenceLabel(context: context, computer: computer),
                                      style: prego.textTheme.textXs.regular.copyWith(
                                        color: prego.colors.textSecondary,
                                      ),
                                      maxLines: null,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                TablerRegular.selector,
                                size: PregoIconSize.sm,
                                color: prego.colors.textTertiary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
    // Under reduced motion no wrapper at all: a zero-length AnimatedSize would
    // re-dirty itself mid-layout.
    if (context.isReducedMotion) return entry;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: AlignmentDirectional.topStart,
      child: entry,
    );
  }
}
