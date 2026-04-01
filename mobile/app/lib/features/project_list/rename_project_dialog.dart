import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/constants.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/widgets/app_modal_bottom_sheet.dart";

/// Shows the Rename Project modal bottom sheet.
///
/// The [cubit] is passed explicitly so the dialog can call
/// `renameProject` without relying on the widget tree's BlocProvider
/// (which lives in the parent screen).
Future<void> showRenameProjectDialog({
  required BuildContext context,
  required Project project,
  required ProjectListCubit cubit,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => RenameProjectDialog(project: project, cubit: cubit),
  );
}

@visibleForTesting
class RenameProjectDialog extends StatefulWidget {
  final Project project;
  final ProjectListCubit cubit;

  const RenameProjectDialog({
    required this.project,
    required this.cubit,
    super.key,
  });

  @override
  State<RenameProjectDialog> createState() => _RenameProjectDialogState();
}

class _RenameProjectDialogState extends State<RenameProjectDialog> {
  late final TextEditingController _nameController;
  bool _actionLoading = false;

  void _dismissDialog() {
    context.pop();
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project.name ?? "");
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final loc = context.loc;

    setState(() => _actionLoading = true);

    final success = await widget.cubit.renameProject(
      projectId: widget.project.id,
      name: name,
    );

    if (!mounted) return;
    setState(() => _actionLoading = false);

    if (success) {
      _dismissDialog();
      messenger.showSnackBar(
        SnackBar(
          content: Text(loc.renameProjectSuccess),
          duration: kSnackBarDuration,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(loc.renameProjectFailed),
          duration: kSnackBarDuration,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(loc.renameProjectTitle, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: loc.renameProjectHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _actionLoading || _nameController.text.trim().isEmpty ? null : _onSave,
              child: _actionLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(loc.renameSave),
            ),
          ),
        ],
      ),
    );
  }
}
