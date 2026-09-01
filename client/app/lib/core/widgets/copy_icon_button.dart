import "dart:async";

import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:theme_prego/module_prego.dart";

/// Small icon button that copies [text] to the clipboard and briefly confirms
/// with a check mark plus light haptic feedback. Self-contained — no snackbar
/// or popup-alert dependency, so it is safe to embed inside a
/// [SelectionArea] (e.g. message cards, code blocks, tool output).
class const CopyIconButton({
  super.key,
  required final String text,
  final String? tooltip,
  final double iconSize = 16,
}) extends StatefulWidget {
  @override
  State<CopyIconButton> createState() => _CopyIconButtonState();
}

class _CopyIconButtonState() extends State<CopyIconButton> {
  /// How long the check mark stays visible after a successful copy.
  static const _confirmationDuration = Duration(milliseconds: 1500);

  bool _copied = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    if (!await copyTextToClipboard(text: widget.text, operation: "text")) return;
    // Haptic is best-effort; its failure must not hide the success state.
    try {
      await HapticFeedback.lightImpact();
    } on Object catch (_) {
      // Nothing to do — haptics are unavailable on this platform/state.
    }
    if (!mounted) return;
    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(_confirmationDuration, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return IconButton(
      onPressed: _copy,
      tooltip: widget.tooltip,
      iconSize: widget.iconSize,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
      icon: Icon(
        _copied ? Icons.check : Icons.copy,
        size: widget.iconSize,
        color: _copied ? prego.colors.fgSuccessPrimary : prego.colors.textSecondary,
      ),
    );
  }
}
