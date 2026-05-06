import "package:flutter/material.dart";

import "../../theme/zyra_theme.dart";
import "../../utils/lerp_utils.dart";

/// Track width for the toggle.
///
/// Figma specifies 50px track width (28px height × 50/28 aspect ratio).
const double _trackWidth = 50.0;

/// Track height for the toggle.
///
/// Figma specifies 28px track height.
const double _trackHeight = 28.0;

/// Thumb diameter.
///
/// Figma specifies 24px thumb in the 28px toggle (28 - 2*2 inset).
const double _thumbSize = 24.0;

/// Inset between thumb edge and track edge.
///
/// Figma specifies 2px padding between thumb and track.
/// 2px = ZyraSpacing.xxs (2px).
const double _thumbInset = ZyraSpacing.xxs;

/// Duration for the toggle animation.
const Duration _animationDuration = Duration(milliseconds: 200);

/// A toggle switch matching the Figma `zyraSwitch` component.
///
/// Renders a pill-shaped track with a circular thumb that slides between
/// the off (start) and on (end) positions with a smooth animation.
///
/// The switch is disabled when [onChanged] is `null`, following the Zyra
/// convention of deriving disabled state from callback nullability.
///
/// Usage:
/// ```dart
/// ZyraSwitch(
///   value: isEnabled,
///   onChanged: (value) => setState(() => isEnabled = value),
/// )
///
/// // Disabled:
/// ZyraSwitch(
///   value: isEnabled,
///   onChanged: null,
/// )
/// ```
class ZyraSwitch extends StatefulWidget {
  const ZyraSwitch({
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
  State<ZyraSwitch> createState() => _ZyraSwitchState();
}

class _ZyraSwitchState extends State<ZyraSwitch> with SingleTickerProviderStateMixin {
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
  void didUpdateWidget(ZyraSwitch oldWidget) {
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
    final colors = context.zyra.colors;
    final isDisabled = widget._isDisabled;

    final trackColorOn = isDisabled ? colors.bgDisabled : colors.bgBrandSolid;
    final trackColorOff = isDisabled ? colors.bgDisabled : colors.bgQuaternary;
    final thumbColor = isDisabled ? colors.toggleButtonFgDisabled : colors.fgWhite;
    final borderColor = colors.toggleBorder;

    return GestureDetector(
      onTap: isDisabled ? null : _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _curvedAnimation,
        builder: (context, child) {
          final animationValue = _curvedAnimation.value;
          final trackColor = lerpColorNonNull(trackColorOff, trackColorOn, animationValue);

          // Thumb slides from _thumbInset to (_trackWidth - _thumbSize - _thumbInset).
          final thumbOffset = _thumbInset + animationValue * (_trackWidth - _thumbSize - _thumbInset * 2);

          return SizedBox(
            width: _trackWidth,
            height: _trackHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(ZyraRadius.full),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Stack(
                children: [
                  if (child case final thumbWidget?)
                    PositionedDirectional(
                      start: thumbOffset,
                      top: _thumbInset,
                      child: thumbWidget,
                    ),
                ],
              ),
            ),
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: thumbColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colors.shadowXs,
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: const SizedBox.square(dimension: _thumbSize),
        ),
      ),
    );
  }
}
