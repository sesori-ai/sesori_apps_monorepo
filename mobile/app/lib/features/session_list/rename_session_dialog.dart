import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/constants.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/widgets/app_modal_bottom_sheet.dart";

/// Shows the Rename Session modal bottom sheet.
///
/// The [cubit] is passed explicitly so the dialog can call
/// `renameSession` without relying on the widget tree's BlocProvider
/// (which lives in the parent screen).
Future<void> showRenameSessionDialog({
  required BuildContext context,
  required Session session,
  required SessionListCubit cubit,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RenameSessionDialog(session: session, cubit: cubit),
  );
}

class _RenameSessionDialog extends StatefulWidget {
  final Session session;
  final SessionListCubit cubit;

  const _RenameSessionDialog({required this.session, required this.cubit});

  @override
  State<_RenameSessionDialog> createState() => _RenameSessionDialogState();
}

class _RenameSessionDialogState extends State<_RenameSessionDialog> {
  late final TextEditingController _controller;
  bool _actionLoading = false;

  void _dismissDialog() {
    context.pop();
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.session.title ?? "");
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final loc = context.loc;

    setState(() => _actionLoading = true);

    final success = await widget.cubit.renameSession(
      sessionId: widget.session.id,
      title: title,
    );

    if (!mounted) return;
    setState(() => _actionLoading = false);

    if (success) {
      _dismissDialog();
      messenger.showSnackBar(
        SnackBar(
          content: Text(loc.renameSessionSuccess),
          duration: kSnackBarDuration,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(loc.renameSessionFailed),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(loc.renameSessionTitle, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: loc.renameSessionHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _onSave(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _actionLoading || _controller.text.trim().isEmpty ? null : _onSave,
            child: _actionLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(loc.renameSave),
          ),
        ],
      ),
    );
  }
}
