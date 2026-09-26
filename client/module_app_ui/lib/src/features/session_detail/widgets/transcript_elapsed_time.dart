import "dart:async";

import "package:clock/clock.dart";
import "package:material_ui/material_ui.dart";

import "../../../extensions/build_context_x.dart";
import "transcript_duration_formatter.dart";

/// The time since [sinceMs] (epoch ms), ticking on each whole elapsed second.
/// Only this text rebuilds as it ticks. It counts from a fixed start, so it
/// reads the same after a reopen or on another device.
class const TranscriptElapsedTime({super.key, required final int sinceMs, required final TextStyle? style})
    extends StatefulWidget {
  @override
  State<TranscriptElapsedTime> createState() => _TranscriptElapsedTimeState();
}

class _TranscriptElapsedTimeState() extends State<TranscriptElapsedTime> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  @override
  void didUpdateWidget(TranscriptElapsedTime oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sinceMs == widget.sinceMs) return;
    _timer?.cancel();
    _scheduleTick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _elapsedMs => clock.now().millisecondsSinceEpoch - widget.sinceMs;

  /// Fires when the next whole second has elapsed; a start still ahead of the
  /// device clock waits until it is reached.
  void _scheduleTick() {
    final elapsed = _elapsedMs;
    final untilNext = elapsed < 0 ? -elapsed : 1000 - elapsed % 1000;
    _timer = Timer(Duration(milliseconds: untilNext), () {
      setState(() {});
      _scheduleTick();
    });
  }

  @override
  Widget build(BuildContext context) => Text(
    TranscriptDurationFormatter.format(
      loc: context.loc,
      duration: Duration(milliseconds: _elapsedMs),
    ),
    style: widget.style,
  );
}
