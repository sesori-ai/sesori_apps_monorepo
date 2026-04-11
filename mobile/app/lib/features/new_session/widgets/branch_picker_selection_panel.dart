import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";

class BranchPickerSelectionPanel extends StatelessWidget {
  final BranchListLoaded state;
  final ValueChanged<WorktreeMode> onModeSelected;
  final VoidCallback onConfirm;

  const BranchPickerSelectionPanel({
    super.key,
    required this.state,
    required this.onModeSelected,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBranch = state.selectedBranch;
    if (selectedBranch == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final loc = context.loc;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.branchPickerActionTitle(selectedBranch.name), style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final mode in state.availableModes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  state.selectedMode == mode ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: state.selectedMode == mode ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
                title: Text(_modeLabel(loc: loc, mode: mode)),
                subtitle: Text(_modeDescription(loc: loc, mode: mode)),
                onTap: () => onModeSelected(mode),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: state.selectedMode == null ? null : onConfirm,
              child: Text(loc.branchPickerConfirmSelection),
            ),
          ],
        ),
      ),
    );
  }

  String _modeLabel({required AppLocalizations loc, required WorktreeMode mode}) {
    return switch (mode) {
      WorktreeMode.stayOnBranch => loc.branchPickerModeStay,
      WorktreeMode.newBranch => loc.branchPickerModeNew,
      WorktreeMode.none => loc.branchPickerProjectDir,
    };
  }

  String _modeDescription({required AppLocalizations loc, required WorktreeMode mode}) {
    return switch (mode) {
      WorktreeMode.stayOnBranch => loc.branchPickerModeStayDescription,
      WorktreeMode.newBranch => loc.branchPickerModeNewDescription,
      WorktreeMode.none => loc.branchPickerNoWorktree,
    };
  }
}
