import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/extensions/build_context_x.dart";

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
  return showPregoBottomSheet<void>(
    context: context,
    title: context.loc.renameProjectTitle,
    builder: (_) => RenameProjectDialog(project: project, cubit: cubit),
  );
}

@visibleForTesting
class const RenameProjectDialog({
  required final Project project,
  required final ProjectListCubit cubit,
  super.key,
}) extends StatefulWidget {
  @override
  State<RenameProjectDialog> createState() => _RenameProjectDialogState();
}

class _RenameProjectDialogState() extends State<RenameProjectDialog> {
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

    final popupAlertPresenter = PregoPopupAlertPresenter.of(context);
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
      popupAlertPresenter.show(
        title: loc.renameProjectSuccess,
        variant: PregoPopupAlertsNotificationsVariant.success,
      );
    } else {
      popupAlertPresenter.show(
        title: loc.renameProjectFailed,
        variant: PregoPopupAlertsNotificationsVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
