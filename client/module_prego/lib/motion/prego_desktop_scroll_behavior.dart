import "package:material_ui/material_ui.dart";

/// A desktop shell's scrolling: vertical scrollbars behave as macOS 27's overlay
/// scroller does, showing with the first tick of a scroll and leaving soon after.
/// The theme can't set a scrollbar's fade, so it is set here.
class const PregoDesktopScrollBehavior() extends MaterialScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    if (axisDirectionToAxis(details.direction) != Axis.vertical) return super.buildScrollbar(context, child, details);
    return RawScrollbar(
      controller: details.controller,
      thickness: 6,
      radius: const Radius.circular(3),
      crossAxisMargin: 3,
      mainAxisMargin: 3,
      minThumbLength: 32,
      interactive: false,
      fadeDuration: const Duration(milliseconds: 100),
      timeToFade: const Duration(milliseconds: 500),
      thumbColor: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(
        alpha: 0.4,
      ),
      child: child,
    );
  }
}
