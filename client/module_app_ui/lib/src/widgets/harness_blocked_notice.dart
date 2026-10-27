import "dart:async";

import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";
import "../features/session_detail/widgets/transcript_motion.dart";

/// Stands in for a composer that cannot send: why, what to do about it, and
/// the way to harness settings, the bridge update steps, and a recheck when
/// each applies.
class const HarnessBlockedNotice({
  super.key,
  required final String title,
  required final String? details,
  required final VoidCallback? onOpenHarnessSettings,
  required final VoidCallback? onShowBridgeUpdate,

  /// Asks again; Recheck shows that it is checking until the returned future
  /// completes.
  required final Future<void> Function()? onRecheck,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final details = this.details;
    final onOpenHarnessSettings = this.onOpenHarnessSettings;
    final onShowBridgeUpdate = this.onShowBridgeUpdate;
    final onRecheck = this.onRecheck;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GlassContainer(
          useOwnLayer: true,
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.all(16),
          shape: const LiquidRoundedSuperellipse(borderRadius: 20),
          settings: LiquidGlassSettings(glassColor: prego.colors.bgSecondary.withValues(alpha: 0.7)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: prego.textTheme.textMd.bold),
              if (details != null && details.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(details, style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary)),
              ],
              if (onOpenHarnessSettings != null || onShowBridgeUpdate != null || onRecheck != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (onOpenHarnessSettings != null)
                      PregoButtonsSolid(
                        key: const Key("session_harness_settings"),
                        label: loc.sessionDetailOpenHarnessSettings,
                        hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                        size: PregoButtonsSolidSize.sm,
                        onPressed: onOpenHarnessSettings,
                      ),
                    if (onShowBridgeUpdate != null)
                      PregoButtonsSolid(
                        key: const Key("session_bridge_update"),
                        label: loc.bridgeUpdateHowTo,
                        hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                        size: PregoButtonsSolidSize.sm,
                        onPressed: onShowBridgeUpdate,
                      ),
                    if (onRecheck != null) _RecheckButton(onRecheck: onRecheck),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Where a press of Recheck stands: none pending, pending for less than
/// [_RecheckButton.checkingDelay], or pending past it and showing so.
enum _RecheckPhase() {
  idle,
  waiting,
  checking,
}

/// Recheck, which shows that it is checking once the answer takes longer than
/// [checkingDelay]: the label cross-fades into a spinner in its room, so the
/// button keeps its size, and it takes no press until the answer. A faster
/// answer never shows the spinner.
class const _RecheckButton({required final Future<void> Function() onRecheck}) extends StatefulWidget {
  static const checkingDelay = Duration(milliseconds: 300);

  @override
  State<_RecheckButton> createState() => _RecheckButtonState();
}

class _RecheckButtonState() extends State<_RecheckButton> {
  _RecheckPhase _phase = _RecheckPhase.idle;
  Timer? _checkingDelay;

  Future<void> _recheck() async {
    if (_phase != _RecheckPhase.idle) return;
    setState(() => _phase = _RecheckPhase.waiting);
    _checkingDelay = Timer(_RecheckButton.checkingDelay, () => setState(() => _phase = _RecheckPhase.checking));
    try {
      await widget.onRecheck();
    } finally {
      _checkingDelay?.cancel();
      if (mounted) setState(() => _phase = _RecheckPhase.idle);
    }
  }

  @override
  void dispose() {
    _checkingDelay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checking = _phase == _RecheckPhase.checking;
    final duration = context.isReducedMotion ? Duration.zero : transcriptMotionDuration;
    // While checking, screen readers hear a disabled Recheck in the button's
    // place. Disabling the button itself would also drop its hover highlight
    // and keyboard focus at once.
    return Semantics(
      container: checking,
      excludeSemantics: checking,
      button: checking ? true : null,
      enabled: checking ? false : null,
      label: checking ? context.loc.sessionDetailRecheck : null,
      child: IgnorePointer(
        ignoring: checking,
        child: TextButton(
          key: const Key("session_harness_recheck"),
          onPressed: () => unawaited(_recheck()),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The label keeps the button its size while the spinner stands in.
              AnimatedOpacity(
                opacity: checking ? 0 : 1,
                duration: duration,
                curve: transcriptMotionCurve,
                alwaysIncludeSemantics: true,
                child: Text(context.loc.sessionDetailRecheck),
              ),
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: transcriptMotionCurve,
                  switchOutCurve: transcriptMotionReverseCurve,
                  child: checking
                      ? const SizedBox.square(
                          key: ValueKey("session_harness_recheck_spinner"),
                          dimension: PregoIconSize.md,
                          child: PregoActivityIndicator(color: null),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
