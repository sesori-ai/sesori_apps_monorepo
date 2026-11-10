import "package:material_ui/material_ui.dart";

import "../../motion/prego_pointer_motion.dart";
import "../../motion/prego_reduced_motion.dart";

/// Optional content at a button's end, such as counts, with the [gap] before
/// it. The slot takes no space while [child] is null. Content is simply there,
/// as on a session switch; only the slot's width eases as content arrives,
/// leaves or changes width, so the button never jumps. Reduced motion applies
/// each change at once.
class const PregoButtonTrailing({super.key, required final double gap, required final Widget? child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final content = switch (child) {
      final child? => Padding(
        padding: EdgeInsetsDirectional.only(start: gap),
        child: child,
      ),
      null => const SizedBox.shrink(),
    };
    // At once under reduced motion, where a zero-length [AnimatedSize] would
    // re-dirty itself mid-layout.
    if (prefersReducedMotion(context)) return content;
    return AnimatedSize(
      duration: pregoPointerExitDuration,
      curve: pregoPointerEnterCurve,
      alignment: AlignmentDirectional.centerEnd,
      child: content,
    );
  }
}
