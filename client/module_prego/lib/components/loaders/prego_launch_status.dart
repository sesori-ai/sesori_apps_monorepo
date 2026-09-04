import "dart:async";

import "package:flutter/foundation.dart";
import "package:material_ui/material_ui.dart";

import "../../motion/prego_reduced_motion.dart";
import "../../theme/prego_theme.dart";
import "prego_activity_indicator.dart";

class const PregoLaunchStatus({
  super.key,
  required final String semanticsLabel,
  required final List<String> messages,
}) extends StatefulWidget {
  @override
  State<PregoLaunchStatus> createState() => _PregoLaunchStatusState();
}

class _PregoLaunchStatusState()
    extends State<PregoLaunchStatus>
    with WidgetsBindingObserver, PregoReducedMotionStateMixin {
  static const _messagePeriod = Duration(milliseconds: 3500);
  static const _transitionDuration = Duration(milliseconds: 200);

  Timer? _messageTimer;
  var _messageIndex = 0;

  @override
  bool get motionEnabled => widget.messages.length > 1;

  @override
  void startMotion() {
    _messageTimer ??= Timer.periodic(_messagePeriod, (_) {
      if (!mounted) return;
      setState(() => _messageIndex = (_messageIndex + 1) % widget.messages.length);
    });
  }

  @override
  void stopMotion() {
    _messageTimer?.cancel();
    _messageTimer = null;
  }

  @override
  void didUpdateWidget(PregoLaunchStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.messages, widget.messages)) {
      _messageIndex = 0;
      syncMotion();
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final reducedMotion = prefersReducedMotion(context);

    return Semantics(
      container: true,
      liveRegion: true,
      label: widget.semanticsLabel,
      child: ExcludeSemantics(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(prego.spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PregoActivityIndicator(color: null),
                SizedBox(height: prego.spacing.xl),
                AnimatedSwitcher(
                  duration: reducedMotion ? Duration.zero : _transitionDuration,
                  child: Text(
                    widget.messages[_messageIndex],
                    key: ValueKey(_messageIndex),
                    textAlign: TextAlign.center,
                    style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textSecondary),
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
