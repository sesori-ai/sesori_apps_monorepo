import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:theme_zyra/module_zyra.dart";

/// Small icon button that copies [text] to the clipboard and briefly confirms
/// with a check mark plus light haptic feedback. Self-contained — no snackbar
/// or `ScaffoldMessenger` dependency, so it is safe to embed inside a
/// [SelectionArea] (e.g. message cards, code blocks, tool output).
class CopyIconButton extends StatefulWidget {
  final String text;
  final String? tooltip;
  final double iconSize;

  const CopyIconButton({
    super.key,
    required this.text,
    this.tooltip,
    this.iconSize = 16,
  });

  @override
  State<CopyIconButton> createState() => _CopyIconButtonState();
}

class _CopyIconButtonState extends State<CopyIconButton> {
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
    await Clipboard.setData(ClipboardData(text: widget.text));
    await HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(_confirmationDuration, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;

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
        color: _copied ? zyra.colors.fgSuccessPrimary : zyra.colors.textSecondary,
      ),
    );
  }
}
