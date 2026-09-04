import "dart:async";

import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";

import "../../theme/prego_theme.dart";

typedef PregoCopyAction = Future<bool> Function();

/// Compact copy action for selectable content.
///
/// [onCopy] owns the platform operation and its failure logging. Returning
/// `true` briefly replaces the copy glyph with a success check and requests
/// best-effort light haptic feedback.
class const PregoCopyIconButton({
  super.key,
  required final PregoCopyAction onCopy,
  final String? tooltip,
  final double iconSize = 16,
}) extends StatefulWidget {
  @override
  State<PregoCopyIconButton> createState() => _PregoCopyIconButtonState();
}

class _PregoCopyIconButtonState() extends State<PregoCopyIconButton> {
  static const _confirmationDuration = Duration(milliseconds: 1500);

  bool _copied = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    if (!await widget.onCopy() || !mounted) return;
    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(_confirmationDuration, () {
      if (mounted) setState(() => _copied = false);
    });
    unawaited(_requestHapticFeedback());
  }

  Future<void> _requestHapticFeedback() async {
    try {
      await HapticFeedback.lightImpact();
    } on Object {
      // Haptics are optional platform feedback; copy success remains valid.
    }
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
