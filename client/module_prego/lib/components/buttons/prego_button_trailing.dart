import "package:material_ui/material_ui.dart";

import "../../motion/prego_reduced_motion.dart";

/// Optional content at a button's end, such as counts, with the [gap] before
/// it. The slot takes no space while [child] is null. When content arrives or
/// leaves, the slot grows or shrinks while the content fades, and a content
/// width change resizes it smoothly, so the button never jumps. Reduced motion
/// applies each change at once.
class const PregoButtonTrailing({super.key, required final double gap, required final Widget? child})
    extends StatelessWidget {
  static const Duration _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final duration = prefersReducedMotion(context) ? Duration.zero : _duration;
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOut,
      // Run backwards, easeIn starts a fold fast.
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (content, animation) => SizeTransition(
        sizeFactor: animation,
        axis: Axis.horizontal,
        alignment: AlignmentDirectional.centerStart,
        child: FadeTransition(opacity: animation, child: content),
      ),
      child: switch (child) {
        final child? => Padding(
          padding: EdgeInsetsDirectional.only(start: gap),
          child: AnimatedSize(
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
