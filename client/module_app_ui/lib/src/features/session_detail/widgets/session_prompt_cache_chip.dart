import "dart:async";

import "package:clock/clock.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// Quiet chip in the session's model row telling how long the model's prompt
/// cache stays warm after its last reply, then that it went cold at [coldAt].
/// It rebuilds only when the visible label changes: at each floored-minute
/// change, then at [coldAt]. Once cold nothing is scheduled.
class const SessionPromptCacheChip({
  super.key,
  required final PregoComposerSurfaceStyle surfaceStyle,
  required final DateTime coldAt,
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
    if (oldWidget.coldAt == widget.coldAt) return;
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
    if (remaining <= Duration.zero) {
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
    final warm = remaining > Duration.zero;
    final label = !warm
        ? loc.sessionPromptCacheCold
        : remaining < const Duration(minutes: 1)
        ? loc.sessionPromptCacheWarmUnderMinute
        : loc.sessionPromptCacheWarm(remaining.inMinutes);
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    final borderRadius = BorderRadius.circular(pointer ? PregoRadius.md : PregoRadius.full);
    return Tooltip(
      message: loc.sessionPromptCacheTooltip,
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
                  warm ? TablerRegular.flame : TablerRegular.snowflake,
                  size: PregoIconSize.sm,
                  color: prego.colors.textSecondary,
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    label,
                    key: ValueKey(label),
                    style: prego.textTheme.textXs.medium.copyWith(
                      color: prego.colors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
