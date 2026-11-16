import "package:flutter/foundation.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "desktop_connection_pill.dart";
import "desktop_page_toolbar.dart";

/// How much of the page's trailing edge a panel floating there, such as a
/// session's side chats, covers as it slides in and out.
///
/// The shell's connection pill keeps clear of it, so it moves with the panel.
/// The page sets it from its panel's own motion, and back to 0 as it goes.
///
/// It holds its notifier rather than being one, so a plain provider shares it
/// without rebuilding the page as it changes.
class DesktopTrailingPanelCover() {
  /// The covered width; 0 while nothing covers the edge.
  final ValueNotifier<double> width = ValueNotifier(0);

  void dispose() => width.dispose();
}

/// The shell's connection pill, under the toolbar at the page's trailing edge
/// and clear of the [DesktopTrailingPanelCover] there, filling the page so it
/// can move across it.
class const DesktopConnectionPillSlot({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => CustomSingleChildLayout(
    // Laid out again rather than rebuilt as the cover changes, so a page may
    // set it while its own tree is torn down.
    delegate: _PillLayout(
      cover: context.read<DesktopTrailingPanelCover>().width,
      textDirection: Directionality.of(context),
    ),
    child: const DesktopConnectionPill(),
  );
}

class _PillLayout({required final ValueListenable<double> cover, required final TextDirection textDirection})
    extends SingleChildLayoutDelegate {
  this : super(relayout: cover);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final fromEnd = PregoSpacing.xl + cover.value;
    final x = switch (textDirection) {
      TextDirection.ltr => size.width - fromEnd - childSize.width,
      TextDirection.rtl => fromEnd,
    };
    return Offset(x, DesktopPageToolbar.height + PregoSpacing.md);
  }

  @override
  bool shouldRelayout(_PillLayout oldDelegate) =>
      oldDelegate.cover != cover || oldDelegate.textDirection != textDirection;
}
