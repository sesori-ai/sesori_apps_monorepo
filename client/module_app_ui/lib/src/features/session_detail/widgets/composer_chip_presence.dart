import "package:material_ui/material_ui.dart";

import "../../../extensions/build_context_x.dart";
import "transcript_motion.dart";

/// A composer status chip that comes and goes while the composer is up. It
/// grows in from the gap before it as it fades up, and folds away fading, so
/// the pickers beside it ease to their new widths rather than jumping. Only
/// this row moves; nothing above it does.
///
/// A chip present on the first build shows at once, as part of the composer.
class const ComposerChipPresence({
  super.key,

  /// The chip, or null while there is none.
  required final Widget? chip,

  /// The room before the chip, which grows and folds with it.
  required final double gap,
}) extends StatefulWidget {
  @override
  State<ComposerChipPresence> createState() => _ComposerChipPresenceState();
}

class _ComposerChipPresenceState() extends State<ComposerChipPresence> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;

  /// What shows, kept while a chip that left folds away.
  late Widget? _shown = widget.chip;

  @override
  void initState() {
    super.initState();
    // Created here, not lazily: a controller first read in didUpdateWidget
    // would start from the new chip and skip its entrance.
    _controller = AnimationController(
      vsync: this,
      duration: transcriptMotionDuration,
      value: widget.chip == null ? 0 : 1,
    )..addStatusListener(_onStatus);
    _curve = CurvedAnimation(
      parent: _controller,
      curve: transcriptMotionCurve,
      reverseCurve: transcriptMotionReverseCurve,
    );
  }

  @override
  void didUpdateWidget(ComposerChipPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    final chip = widget.chip;
    final reduced = context.isReducedMotion;
    if (chip != null) {
      _shown = chip;
      if (reduced) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    } else if (reduced) {
      _controller.value = 0;
      _shown = null;
    } else {
      _controller.reverse();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && widget.chip == null && mounted) setState(() => _shown = null);
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown == null) return const SizedBox.shrink();
    return SizeTransition(
      axis: Axis.horizontal,
      alignment: AlignmentDirectional.centerStart,
      sizeFactor: _curve,
      child: FadeTransition(
        opacity: _curve,
        child: Padding(
          padding: EdgeInsetsDirectional.only(start: widget.gap),
          child: shown,
        ),
      ),
    );
  }
}
