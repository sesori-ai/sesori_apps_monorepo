import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";

/// Dialog that lets the user pick a [WorktreeMode] after selecting a branch.
class BranchModePickerDialog extends StatelessWidget {
  final List<WorktreeMode> modes;
  final ValueChanged<WorktreeMode> onModeSelected;

  const BranchModePickerDialog({
    super.key,
    required this.modes,
    required this.onModeSelected,
  });

  static void show({
    required BuildContext context,
    required List<WorktreeMode> modes,
    required ValueChanged<WorktreeMode> onModeSelected,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => BranchModePickerDialog(
        modes: modes,
        onModeSelected: onModeSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in modes)
            ListTile(
              title: Text(_modeLabel(mode: mode, loc: loc)),
              leading: Icon(_modeIcon(mode: mode)),
              onTap: () {
                Navigator.of(context).pop();
                onModeSelected(mode);
              },
            ),
        ],
      ),
    );
  }

  String _modeLabel({
    required WorktreeMode mode,
    required AppLocalizations loc,
  }) {
    return switch (mode) {
      WorktreeMode.stayOnBranch => loc.branchPickerModeStay,
      WorktreeMode.newBranch => loc.branchPickerModeNew,
      WorktreeMode.none => loc.branchPickerProjectDir,
    };
  }

  IconData _modeIcon({required WorktreeMode mode}) {
    return switch (mode) {
      WorktreeMode.stayOnBranch => Icons.alt_route,
      WorktreeMode.newBranch => Icons.add_road,
      WorktreeMode.none => Icons.folder_outlined,
    };
  }
}
