import "dart:async";

import "package:clock/clock.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// Quiet chip in the session's model row telling how long the model's prompt
/// cache stays warm after its last reply, then that it went cold at [coldAt].
/// While a turn runs ([inUse]) it reads warm without counting down. It
/// rebuilds only when the visible label changes: at each floored-minute
/// change, then at [coldAt]. Once cold or in use nothing is scheduled. The
/// label slot is as wide as the widest label, so the chip never resizes the
/// pickers beside it.
class const SessionPromptCacheChip({
  super.key,
  required final PregoComposerSurfaceStyle surfaceStyle,
  required final DateTime coldAt,
  required final bool inUse,
}) extends StatefulWidget {
  @override
  State<SessionPromptCacheChip> createState() => _SessionPromptCacheChipState();
}

class _SessionPromptCacheChipState() extends State<SessionPromptCacheChip> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleChange();
  }

  @override
  void didUpdateWidget(SessionPromptCacheChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coldAt == widget.coldAt && oldWidget.inUse == widget.inUse) return;
    _timer?.cancel();
    _scheduleChange();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration get _remaining => widget.coldAt.difference(clock.now());

  /// Fires once the floored minutes drop, or at [SessionPromptCacheChip.coldAt]
  /// during the final minute.
  void _scheduleChange() {
    final remaining = _remaining;
    if (widget.inUse || remaining <= Duration.zero) {
      _timer = null;
      return;
    }
    final untilChange = remaining < const Duration(minutes: 1)
        ? remaining
        : remaining - Duration(minutes: remaining.inMinutes) + const Duration(microseconds: 1);
    _timer = Timer(untilChange, () {
      setState(() {});
      _scheduleChange();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final remaining = _remaining;
    final cold = !widget.inUse && remaining <= Duration.zero;
    final (label, tooltip) = widget.inUse
        ? (loc.sessionPromptCacheInUse, loc.sessionPromptCacheTooltipInUse)
        : cold
        ? (loc.sessionPromptCacheCold, loc.sessionPromptCacheTooltipCold)
        : remaining < const Duration(minutes: 1)
        ? (loc.sessionPromptCacheWarmUnderMinute, loc.sessionPromptCacheTooltipWarm)
        : (loc.sessionPromptCacheWarm(remaining.inMinutes), loc.sessionPromptCacheTooltipWarm);
    final style = prego.textTheme.textXs.medium.copyWith(
      color: prego.colors.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final labelWidth = _widestLabelWidth(context: context, style: style);
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    final borderRadius = BorderRadius.circular(pointer ? PregoRadius.md : PregoRadius.full);
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        key: const Key("session-prompt-cache-chip"),
        height: pointer ? 28.0 : 36.0,
        child: DecoratedBox(
          decoration: pregoComposerSurfaceDecoration(
            prego: prego,
            style: widget.surfaceStyle,
            borderRadius: borderRadius,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: pointer ? 9 : 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Icon(
                  cold ? TablerRegular.snowflake : TablerRegular.flame,
                  size: PregoIconSize.sm,
                  color: prego.colors.textSecondary,
                ),
                SizedBox(
                  width: labelWidth,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: AlignmentDirectional.centerStart,
                      children: [...previous, ?current],
                    ),
                    child: Text(label, key: ValueKey(label), maxLines: 1, softWrap: false, style: style),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The widest label the chip can show, so every state has the same width.
  /// Two-digit minutes cover any cache lifetime under 100 minutes.
  double _widestLabelWidth({required BuildContext context, required TextStyle style}) {
    final loc = context.loc;
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    var widest = 0.0;
    for (final label in [
      loc.sessionPromptCacheInUse,
      loc.sessionPromptCacheCold,
      loc.sessionPromptCacheWarmUnderMinute,
      loc.sessionPromptCacheWarm(88),
    ]) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest.ceilToDouble();
  }
}
