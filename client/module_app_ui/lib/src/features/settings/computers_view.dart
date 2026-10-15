import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../widgets/computer_menu.dart";
import "widgets/settings_window_page.dart";

/// Vertical inset between the nav bar and the list.
const double _contentTopPadding = 10.0;

/// Wide enough for the longest action and the hint under a disabled Remove…
/// without the menu covering its row.
const double _menuWidth = 300;

/// Every computer on the account, in the computer menu's order, each with its
/// actions behind a "⋯" button or a secondary click on its row.
///
/// Reads the rows from [ComputerSwitcherCubit] and runs renames and removals
/// through [ComputersCubit], both provided by the product shell. A change
/// reaches the rows through the account's shared list, so a renamed row
/// changes in place and a removed one closes.
class const ComputersView({
  super.key,
  required final SettingsPageChrome chrome,

  /// Switches to a computer picked from its row's menu, and away from the
  /// computer the app works on once it is removed.
  required final ComputerSwitchCallback onSwitchComputer,

  /// Builds the action that turns off this computer's own bridge, shown in
  /// the dialog that explains why this computer cannot be removed. It builds
  /// nothing while the bridge is off. `null` on a surface without a bridge of
  /// its own (the phone).
  required final WidgetBuilder? localBridgeTurnOffActionBuilder,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ComputerSwitcherCubit>().state;
    final busyId = switch (context.watch<ComputersCubit>().state) {
      ComputersRenaming(:final bridgeId) || ComputersRemoving(:final bridgeId) => bridgeId,
      ComputersIdle() || ComputersRenameFailed() || ComputersRemoveFailed() => null,
    };
    return BlocListener<ComputersCubit, ComputersState>(
      listener: (context, state) {
        final failure = switch (state) {
          ComputersRenameFailed() => context.loc.computersRenameFailed,
          ComputersRemoveFailed() => context.loc.computersRemoveFailed,
          ComputersIdle() || ComputersRenaming() || ComputersRemoving() => null,
        };
        if (failure == null) return;
        PregoPopupAlertPresenter.of(context).show(
          title: failure,
          variant: PregoPopupAlertsNotificationsVariant.error,
        );
      },
      child: SettingsChromePage(
        chrome: chrome,
        slivers: [
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(
              PregoSpacing.xl,
              _contentTopPadding,
              PregoSpacing.xl,
              PregoSpacing.xl + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverToBoxAdapter(
              child: PregoGroupedRows(
                children: [
                  // A removed row closes while the rows below it rise into its
                  // place; the rows above it stay still.
                  PregoAnimatedList<BridgeSummary>(
                    items: state.computers,
                    itemKey: (computer) => ValueKey(computer.id),
                    itemBuilder: (context, index, computer) => PregoGroupedRowPosition(
                      isLast: index == state.computers.length - 1,
                      child: _ComputerRow(
                        key: ValueKey("computers-row-${computer.id}"),
                        computer: computer,
                        isCurrent: computer.id == state.currentId,
                        isThisComputer: state.isThisComputer(bridgeId: computer.id),
                        canRemove: state.canRemove(bridgeId: computer.id),
                        isBusy: computer.id == busyId,
                        isActionRunning: busyId != null,
                        localBridgeTurnOffActionBuilder: localBridgeTurnOffActionBuilder,
                        onSwitch: () =>
                            onSwitchComputer(bridgeId: computer.id, source: ComputerSwitchSource.computersPage),
                        onRemove: () => unawaited(_remove(context: context, bridgeId: computer.id)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Removes [bridgeId], then moves the app to another computer when it was
  /// working on that one, as a switch from this page would.
  Future<void> _remove({required BuildContext context, required String bridgeId}) async {
    final computers = context.read<ComputerSwitcherCubit>().state;
    // It may have come online while the user confirmed.
    if (!computers.canRemove(bridgeId: bridgeId)) return;
    final replacement = await context.read<ComputersCubit>().remove(
      bridgeId: bridgeId,
      isCurrent: bridgeId == computers.currentId,
    );
    if (replacement == null) return;
    onSwitchComputer(bridgeId: replacement, source: ComputerSwitchSource.computersPage);
  }
}

/// One computer: platform, name, the hostname under a name of its own, and
/// presence; a check when the app works on it.
class const _ComputerRow({
  super.key,
  required final BridgeSummary computer,
  required final bool isCurrent,
  required final bool isThisComputer,
  required final bool canRemove,

  /// Whether an action on this computer is running; its "⋯" waits for it.
  required final bool isBusy,

  /// Whether an action on any computer is running; Rename and Remove wait
  /// for it, so one action runs at a time.
  required final bool isActionRunning,
  required final WidgetBuilder? localBridgeTurnOffActionBuilder,
  required final VoidCallback onSwitch,

  /// Removes the computer once the user has confirmed it.
  required final VoidCallback onRemove,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    return PregoAnchorMenu(
      // A flat panel beside the row; a glass popup would morph out of the
      // whole row.
      flat: true,
      acquireOpenLease: null,
      menuWidth: _menuWidth,
      entriesBuilder: () => [
        if (!isCurrent)
          PregoMenuItem(
            key: ValueKey("computers-switch-${computer.id}"),
            title: loc.computersSwitch,
            subtitle: null,
            leadingIcon: TablerRegular.switch_horizontal,
            isSelected: false,
            shortcutLabel: null,
            onTap: onSwitch,
          ),
        PregoMenuItem(
          key: ValueKey("computers-rename-${computer.id}"),
          title: loc.computersRename,
          subtitle: null,
          leadingIcon: TablerRegular.pencil,
          isSelected: false,
          shortcutLabel: null,
          isEnabled: !isActionRunning,
          // The menu has closed by now; the row it hung off is still here.
          onTap: () => unawaited(_rename(context: context)),
        ),
        PregoMenuItem(
          key: ValueKey("computers-remove-${computer.id}"),
          title: loc.computersRemove,
          // Only an online computer other than this one waits, and says why.
          subtitle: isThisComputer || canRemove ? null : loc.computersRemoveOnlineHint(computer.name),
          leadingIcon: TablerRegular.trash,
          isSelected: false,
          shortcutLabel: null,
          isEnabled: isThisComputer || (canRemove && !isActionRunning),
          isDestructive: canRemove,
          onTap: () =>
              unawaited(isThisComputer ? _explainThisComputer(context: context) : _confirmRemove(context: context)),
        ),
      ],
      triggerBuilder: (context, openMenu) => GestureDetector(
        onSecondaryTap: isBusy ? null : openMenu,
        child: PregoGroupedRow(
          icon: ComputerMenu.platformIcon(platform: computer.platform),
          title: Row(
            spacing: PregoSpacing.sm,
            children: [
              Flexible(child: Text(computer.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (isThisComputer) PregoTag(label: loc.desktopSettingsThisComputer),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Only a name of the user's own hides the machine's.
              if (computer.hostname != computer.name)
                Text(
                  computer.hostname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
                ),
              Text(ComputerMenu.presenceLabel(context: context, computer: computer)),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: PregoSpacing.xs,
            children: [
              if (isCurrent) Icon(TablerRegular.check, size: PregoIconSize.sm, color: prego.colors.bgBrandSolid),
              Semantics(
                label: loc.computersActions(computer.name),
                child: Tooltip(
                  message: loc.computersActions(computer.name),
                  excludeFromSemantics: true,
                  child: PregoButtonsSolid.iconOnly(
                    key: ValueKey("computers-actions-${computer.id}"),
                    leadingIcon: TablerRegular.dots,
                    hierarchy: PregoButtonsSolidHierarchy.tertiary,
                    size: PregoButtonsSolidSize.sm,
                    // The spinner takes the button's place, so the row keeps its size.
                    isLoading: isBusy,
                    onPressed: isBusy ? null : openMenu,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemove({required BuildContext context}) async {
    final confirmed = await showPregoModal<bool>(
      context: context,
      title: context.loc.computersRemoveTitle(computer.name),
      builder: (_) => const _RemoveConfirmation(),
    );
    if (confirmed ?? false) onRemove();
  }

  Future<void> _explainThisComputer({required BuildContext context}) => showPregoModal<void>(
    context: context,
    title: context.loc.computersThisComputerTitle,
    builder: (_) => _ThisComputerExplanation(turnOffActionBuilder: localBridgeTurnOffActionBuilder),
  );

  Future<void> _rename({required BuildContext context}) {
    final cubit = context.read<ComputersCubit>();
    return showPregoModal<void>(
      context: context,
      title: context.loc.computersRenameTitle,
      builder: (_) => _RenameComputerSheet(
        computer: computer,
        onRename: ({required name}) => unawaited(cubit.rename(computer: computer, name: name)),
      ),
    );
  }
}

/// Edits the name of [computer], prefilled with its current one. "Use
/// hostname" saves the hostname, which `ComputersCubit` turns into clearing
/// the name of its own.
class const _RenameComputerSheet({
  required final BridgeSummary computer,
  required final void Function({required String name}) onRename,
}) extends StatefulWidget {
  @override
  State<_RenameComputerSheet> createState() => _RenameComputerSheetState();
}

class _RenameComputerSheetState() extends State<_RenameComputerSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.computer.name);

  /// Whether the computer has a name of its own, so its hostname is an option.
  bool get _hasNickname => widget.computer.name != widget.computer.hostname;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save({required String value}) {
    context.pop();
    widget.onRename(name: value);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final save = PregoButtonsSolid(
      key: const Key("computers-rename-save"),
      label: loc.renameSave,
      hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
      size: PregoButtonsSolidSize.lg,
      fullWidth: true,
      onPressed: () => _save(value: _controller.text),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PregoInputField(
            key: const Key("computers-rename-field"),
            controller: _controller,
            label: loc.computersRenameLabel,
            autofocus: true,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => _save(value: value),
          ),
          const SizedBox(height: PregoSpacing.x2l),
          if (_hasNickname)
            PregoSheetActions(
              secondary: PregoButtonsSolid(
                key: const Key("computers-rename-use-hostname"),
                label: loc.computersRenameUseHostname,
                hierarchy: PregoButtonsSolidHierarchy.secondary,
                size: PregoButtonsSolidSize.lg,
                fullWidth: true,
                onPressed: () => _save(value: widget.computer.hostname),
              ),
              primary: save,
            )
          else
            save,
        ],
      ),
    );
  }
}

/// The remove question's body: what removing means, then Cancel and a
/// destructive Remove that answers `true`.
class const _RemoveConfirmation() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.computersRemoveMessage,
            style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
          ),
          const SizedBox(height: PregoSpacing.x2l),
          PregoSheetActions(
            secondary: PregoButtonsSolid(
              key: const Key("computers-remove-cancel"),
              label: loc.computersRemoveCancel,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.lg,
              fullWidth: true,
              onPressed: () => context.pop(),
            ),
            primary: PregoButtonsSolid(
              key: const Key("computers-remove-confirm"),
              label: loc.computersRemoveConfirm,
              hierarchy: PregoButtonsSolidHierarchy.primary,
              type: PregoButtonsSolidType.destructive,
              size: PregoButtonsSolidSize.lg,
              fullWidth: true,
              onPressed: () => context.pop(true),
            ),
          ),
        ],
      ),
    );
  }
}

/// Why the computer in use cannot be removed, with the shell's action that
/// turns off its bridge above Close. That action builds nothing while the
/// bridge is off, and the dialog eases into the space it leaves.
class const _ThisComputerExplanation({required final WidgetBuilder? turnOffActionBuilder}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final turnOffActionBuilder = this.turnOffActionBuilder;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.computersThisComputerMessage,
            style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
          ),
          const SizedBox(height: PregoSpacing.x2l),
          if (turnOffActionBuilder != null)
            AnimatedSize(
              duration: context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: AlignmentDirectional.topCenter,
              child: Builder(builder: turnOffActionBuilder),
            ),
          PregoButtonsSolid(
            key: const Key("computers-this-computer-close"),
            label: loc.computersThisComputerClose,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.lg,
            fullWidth: true,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}
