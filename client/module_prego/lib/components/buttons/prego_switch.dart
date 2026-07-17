import "package:flutter/material.dart";

import "../../theme/prego_theme.dart";
import "../../utils/lerp_utils.dart";

/// Track width for the toggle.
///
/// Figma `Toggle - Switch` specifies a 64px track width.
const double _trackWidth = 64.0;

/// Track height for the toggle.
///
/// Figma specifies 28px track height.
const double _trackHeight = 28.0;

/// Knob width.
///
/// Figma specifies a wide 39×24 pill knob inside the 64×28 track.
const double _knobWidth = 39.0;

/// Knob height.
const double _knobHeight = 24.0;

/// Inset between knob edge and track edge.
///
/// Figma specifies 2px padding between knob and track.
/// 2px = PregoSpacing.xxs (2px).
const double _knobInset = PregoSpacing.xxs;

/// Duration for the toggle animation.
const Duration _animationDuration = Duration(milliseconds: 200);

/// A toggle switch matching the Figma `Toggle - Switch` component.
///
/// Renders a pill-shaped track with a wide pill knob that slides between
/// the off (start) and on (end) positions with a smooth animation. The track
/// fills with the brand colour when on and a subtle alpha tint when off.
///
/// The switch is disabled when [onChanged] is `null`, following the Prego
/// convention of deriving disabled state from callback nullability.
///
/// Usage:
/// ```dart
/// PregoSwitch(
///   value: isEnabled,
///   onChanged: (value) => setState(() => isEnabled = value),
/// )
///
/// // Disabled:
/// PregoSwitch(
///   value: isEnabled,
///   onChanged: null,
/// )
/// ```
class PregoSwitch extends StatefulWidget {
  const PregoSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// Whether the switch is on (`true`) or off (`false`).
  final bool value;

  /// Called when the user toggles the switch. Pass `null` to disable.
  final ValueChanged<bool>? onChanged;

  bool get _isDisabled => onChanged == null;

  @override
  State<PregoSwitch> createState() => _PregoSwitchState();
}

class _PregoSwitchState extends State<PregoSwitch> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curvedAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
      value: widget.value ? 1.0 : 0.0,
    );
    _curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(PregoSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _curvedAnimation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    widget.onChanged?.call(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    final isDisabled = widget._isDisabled;

    final trackColorOn = isDisabled ? colors.bgDisabled : colors.bgBrandSolid;
    final trackColorOff = isDisabled ? colors.bgDisabled : colors.alphaBlack10;
    final knobColor = isDisabled ? colors.toggleButtonFgDisabled : colors.fgWhite;

    return Semantics(
      toggled: widget.value,
      enabled: !isDisabled,
      onTap: isDisabled ? null : _handleTap,
      child: GestureDetector(
        onTap: isDisabled ? null : _handleTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _curvedAnimation,
          builder: (context, child) {
            final animationValue = _curvedAnimation.value;
            final trackColor = lerpColorNonNull(trackColorOff, trackColorOn, animationValue);

            // Knob slides from _knobInset to (_trackWidth - _knobWidth - _knobInset).
            final knobOffset = _knobInset + animationValue * (_trackWidth - _knobWidth - _knobInset * 2);

            return SizedBox(
              width: _trackWidth,
              height: _trackHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(PregoRadius.full),
                ),
                child: Stack(
                  children: [
                    if (child case final knobWidget?)
                      PositionedDirectional(
                        start: knobOffset,
                        top: _knobInset,
                        child: knobWidget,
                      ),
                  ],
                ),
              ),
            );
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: knobColor,
              borderRadius: BorderRadius.circular(PregoRadius.full),
            ),
            child: const SizedBox(width: _knobWidth, height: _knobHeight),
          ),
        ),
      ),
    );
  }
}
