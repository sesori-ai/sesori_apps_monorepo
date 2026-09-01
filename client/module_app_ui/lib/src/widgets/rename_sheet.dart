import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

class const RenameSheet({
  required final String initialValue,
  required final String hintText,
  required final String saveLabel,
  required final String successMessage,
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
  bool _loading = false;

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

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty || _loading) return;
    final presenter = PregoPopupAlertPresenter.of(context);
    setState(() => _loading = true);
    final success = await widget.onRename(value);
    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      context.pop();
      presenter.show(title: widget.successMessage, variant: PregoPopupAlertsNotificationsVariant.success);
    } else {
      presenter.show(title: widget.failureMessage, variant: PregoPopupAlertsNotificationsVariant.error);
    }
  }

  static Brightness _inverse(Brightness brightness) =>
      brightness == Brightness.dark ? Brightness.light : Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final action = FilledButton(
      onPressed: _loading || _controller.text.trim().isEmpty ? null : _save,
      child: _loading
          ? SizedBox(
              width: 16,
              height: 16,
              // The primary button paints the inverse of the page surface, so
              // the spinner takes the untinted grey of the opposite brightness.
              child: PregoActivityIndicator(
                color: PregoActivityIndicator.naturalColor(brightness: _inverse(Theme.of(context).brightness)),
              ),
            )
          : Text(widget.saveLabel),
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
