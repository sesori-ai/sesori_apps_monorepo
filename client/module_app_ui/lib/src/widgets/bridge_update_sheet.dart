import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart" show BridgeKind;
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";
import "../utils/bridge_install.dart";
import "../utils/copy_text_to_clipboard.dart";

/// Opens the steps that update the connected bridge over the current screen.
///
/// Every notice that the connected bridge is too old for a feature offers this
/// one sheet, because the fix happens on the computer running the bridge, not
/// in the app. A bridge Sesori Desktop bundles is updated by that app, so it
/// gets the desktop steps; any other bridge, or one not connected yet, gets the
/// command-line steps. Their reinstall commands stay visible: bridges released
/// before the update command cannot follow step 1.
Future<void> showBridgeUpdateSheet({required BuildContext context}) {
  final loc = context.loc;
  final (title, steps) = switch (context.read<BridgeKindCubit>().state) {
    BridgeKind.desktop => (loc.bridgeUpdateDesktopTitle, const _DesktopUpdateSteps()),
    BridgeKind.cli || null => (loc.bridgeUpdateTitle, const _BridgeUpdateSteps()),
  };
  return showPregoModal<void>(
    context: context,
    title: title,
    width: PregoModalWidth.request,
    builder: (_) => steps,
  );
}

/// The "How to update ›" trailing a settings row whose tap opens
/// [showBridgeUpdateSheet], matching the value-and-chevron rows that open an
/// editor.
class const BridgeUpdateRowTrailing({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: PregoSpacing.xs,
      children: [
        Text(
          context.loc.bridgeUpdateHowTo,
          style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textBrandSecondary),
        ),
        Icon(TablerRegular.chevron_right, size: PregoIconSize.sm, color: prego.colors.textTertiary),
      ],
    );
  }
}

class const _BridgeUpdateSteps() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final body = prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary);
    final heading = prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(loc.bridgeUpdateIntro, style: body),
          const SizedBox(height: PregoSpacing.xl),
          Text(loc.bridgeUpdateStepUpdate, style: heading),
          const SizedBox(height: PregoSpacing.md),
          _CommandBox(command: BridgeInstall.updateCommand, copyTooltip: loc.bridgeUpdateCopyCommand),
          const SizedBox(height: PregoSpacing.xl),
          Text(loc.bridgeUpdateStepRestart, style: heading),
          const SizedBox(height: PregoSpacing.md),
          _CommandBox(command: BridgeInstall.runCommand, copyTooltip: loc.bridgeUpdateCopyCommand),
          const SizedBox(height: PregoSpacing.md),
          Text(loc.bridgeUpdateRestartService, style: body),
          const SizedBox(height: PregoSpacing.x3l),
          Text(loc.bridgeUpdateReinstallIntro, style: heading),
          _LabeledCommand(label: loc.bridgeUpdateMethodMacLinux, command: BridgeInstall.macLinuxCommand),
          _LabeledCommand(label: loc.bridgeUpdateMethodWindows, command: BridgeInstall.windowsCommand),
          _LabeledCommand(label: loc.bridgeUpdateMethodNpm, command: BridgeInstall.npmCommand),
          _LabeledCommand(label: loc.bridgeUpdateMethodBun, command: BridgeInstall.bunCommand),
          const SizedBox(height: PregoSpacing.lg),
          Text(loc.bridgeUpdateReinstallRestart, style: body),
        ],
      ),
    );
  }
}

/// Sesori Desktop updates the bridge it bundles, so there is no command to
/// run: install the app's update, or fetch the latest app when none shows up.
class const _DesktopUpdateSteps() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final heading = prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            loc.bridgeUpdateDesktopIntro,
            style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
          ),
          const SizedBox(height: PregoSpacing.xl),
          Text(loc.bridgeUpdateDesktopStepUpdate, style: heading),
          const SizedBox(height: PregoSpacing.xl),
          Text(loc.bridgeUpdateDesktopStepDownload, style: heading),
          const SizedBox(height: PregoSpacing.md),
          _CommandBox(command: BridgeInstall.desktopDownloadPage, copyTooltip: loc.bridgeUpdateCopyLink),
        ],
      ),
    );
  }
}

class const _LabeledCommand({required final String label, required final String command}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: PregoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: PregoSpacing.sm,
        children: [
          Text(label, style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textTertiary)),
          _CommandBox(command: command, copyTooltip: context.loc.bridgeUpdateCopyCommand),
        ],
      ),
    );
  }
}

/// One command (or link) in monospace with a copy button. A long command wraps
/// rather than scrolls, so the whole of it is always readable.
class const _CommandBox({required final String command, required final String copyTooltip}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: prego.colors.bgSurface2,
        borderRadius: BorderRadius.circular(PregoRadius.md),
        border: Border.all(color: prego.colors.borderSecondary),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          PregoSpacing.lg,
          PregoSpacing.sm,
          PregoSpacing.sm,
          PregoSpacing.sm,
        ),
        child: Row(
          spacing: PregoSpacing.md,
          children: [
            Expanded(
              child: SelectableText(command, style: prego.textTheme.code.copyWith(color: prego.colors.textPrimary)),
            ),
            PregoCopyIconButton(
              key: ValueKey("bridge_update_copy_$command"),
              tooltip: copyTooltip,
              onCopy: () => copyTextToClipboard(text: command, operation: "bridge update command"),
            ),
          ],
        ),
      ),
    );
  }
}
