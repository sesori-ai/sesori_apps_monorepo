import "dart:async";

import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

class const RenameSheet({
  required final String initialValue,
  required final String hintText,
  required final String saveLabel,
  required final String failureMessage,
  required final Future<bool> Function(String value) onRename,
  final bool submitOnEnter = false,
  final double? actionHeight,
  super.key,
}) extends StatefulWidget {
  @override
  State<RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState() extends State<RenameSheet> {
  late final TextEditingController _controller;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty || _submitted) return;

    final presenter = PregoPopupAlertPresenter.of(context);
    setState(() => _submitted = true);
    final rename = widget.onRename(value);
    context.pop();
    unawaited(
      _showFailureIfNeeded(
        rename: rename,
        presenter: presenter,
        failureMessage: widget.failureMessage,
      ),
    );
  }

  Future<void> _showFailureIfNeeded({
    required Future<bool> rename,
    required PregoPopupAlertPresenter presenter,
    required String failureMessage,
  }) async {
    final bool succeeded;
    try {
      succeeded = await rename;
    } on Object {
      presenter.show(title: failureMessage, variant: PregoPopupAlertsNotificationsVariant.error);
      return;
    }
    if (!succeeded) {
      presenter.show(title: failureMessage, variant: PregoPopupAlertsNotificationsVariant.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = FilledButton(
      onPressed: _submitted || _controller.text.trim().isEmpty ? null : _save,
      child: Text(widget.saveLabel),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(hintText: widget.hintText, border: const OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
            onSubmitted: widget.submitOnEnter ? (_) => _save() : null,
          ),
          const SizedBox(height: 16),
          if (widget.actionHeight case final height?) SizedBox(height: height, child: action) else action,
        ],
      ),
    );
  }
}
