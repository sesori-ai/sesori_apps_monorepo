import "package:material_ui/material_ui.dart";

import "../../interactions/prego_interaction_scope.dart";
import "../../motion/prego_pointer_motion.dart";
import "../../motion/prego_reduced_motion.dart";

/// Optional content at a button's end, such as counts, with the [gap] before
/// it. The slot takes no space while [child] is null. When content arrives or
/// leaves, the slot grows or shrinks while the content fades, and a content
/// width change resizes it smoothly, so the button never jumps. Reduced motion
/// applies each change at once.
class const PregoButtonTrailing({super.key, required final double gap, required final Widget? child})
    extends StatelessWidget {
  static const Duration _duration = Duration(milliseconds: 200);

  /// A pointer shell's width change: quick, and at once under reduced motion,
  /// where a zero-length [AnimatedSize] would re-dirty itself mid-layout.
  Widget _eased({required bool reducedMotion, required Widget child}) => reducedMotion
      ? child
      : AnimatedSize(
          duration: pregoPointerExitDuration,
          curve: pregoPointerEnterCurve,
          alignment: AlignmentDirectional.centerEnd,
          child: child,
        );

  @override
  Widget build(BuildContext context) {
    final reducedMotion = prefersReducedMotion(context);
    final duration = reducedMotion ? Duration.zero : _duration;
    // Under a pointer the content is simply there on a session switch; only a
    // later change in its width eases.
    if (PregoInteractionScope.of(context) == PregoInteractionMode.pointer) {
      return switch (child) {
        final child? => _eased(
          reducedMotion: reducedMotion,
          child: Padding(
            padding: EdgeInsetsDirectional.only(start: gap),
            child: child,
          ),
        ),
        null => _eased(reducedMotion: reducedMotion, child: const SizedBox.shrink()),
      };
    }
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOut,
      // Run backwards, easeIn starts a fold fast.
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (content, animation) => SizeTransition(
        sizeFactor: animation,
        axis: Axis.horizontal,
        alignment: AlignmentDirectional.centerStart,
        // Keep the content's own height; unset, it fills the available height.
        fixedCrossAxisSizeFactor: 1,
        child: FadeTransition(opacity: animation, child: content),
      ),
      child: switch (child) {
        final child? => Padding(
          padding: EdgeInsetsDirectional.only(start: gap),
          // Under reduced motion no wrapper at all: a zero-length AnimatedSize
          // would re-dirty itself mid-layout.
          child: reducedMotion
              ? child
              : AnimatedSize(
                  duration: duration,
                  curve: Curves.easeOut,
                  alignment: AlignmentDirectional.centerStart,
                  child: child,
                ),
        ),
        null => const SizedBox.shrink(),
      },
    );
  }
}
