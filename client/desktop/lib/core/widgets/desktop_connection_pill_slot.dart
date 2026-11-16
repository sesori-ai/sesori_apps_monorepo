import "package:flutter/foundation.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "desktop_connection_pill.dart";
import "desktop_page_toolbar.dart";

/// The page's trailing edge as a panel floating there, such as a session's
/// side chats, covers it: [DesktopPanelCoverage.width] once the panel has
/// settled, and how far it has slid in, from 0 to 1.
typedef DesktopPanelCoverage = ({double width, double shown});

/// What a panel floating at the page's trailing edge covers of it as it slides
/// in and out.
///
/// The shell's connection pill keeps clear of it, so it moves with the panel.
/// The page on top sets it from its panel's own motion; a page kept under a
/// pushed one, or going away, clears only what it set itself.
///
/// It holds its notifier rather than being one, so a plain provider shares it
/// without rebuilding the page as it changes.
class DesktopTrailingPanelCover() {
  final _coverage = ValueNotifier<DesktopPanelCoverage>(_uncovered);

  /// Who set [coverage] last, so another page's leaving keeps it.
  Object? _coveredBy;

  static const DesktopPanelCoverage _uncovered = (width: 0, shown: 0);

  /// Nothing covers the edge while [DesktopPanelCoverage.shown] is 0.
  ValueListenable<DesktopPanelCoverage> get coverage => _coverage;

  /// Sets the coverage for [by], the page whose panel covers the edge.
  void cover({required Object by, required double width, required double shown}) {
    _coveredBy = by;
    _coverage.value = (width: width, shown: shown);
  }

  /// Clears the cover when [by] set it last.
  void release({required Object by}) {
    if (_coveredBy != by) return;
    _coveredBy = null;
    _coverage.value = _uncovered;
  }

  void dispose() => _coverage.dispose();
}

/// The shell's connection pill, under the toolbar at the page's trailing edge
/// and clear of the [DesktopTrailingPanelCover] there, filling the page so it
/// can move across it. Where the page leaves it no room beside the panel, it
/// moves to the page's middle instead, over the panel's top, to stay in view.
class const DesktopConnectionPillSlot({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => CustomSingleChildLayout(
    // Laid out again rather than rebuilt as the cover changes, so a page may
    // set it while its own tree is torn down.
    delegate: _PillLayout(
      cover: context.read<DesktopTrailingPanelCover>().coverage,
      textDirection: Directionality.of(context),
    ),
    child: const DesktopConnectionPill(),
  );
}

class _PillLayout({
  required final ValueListenable<DesktopPanelCoverage> cover,
  required final TextDirection textDirection,
}) extends SingleChildLayoutDelegate {
  this : super(relayout: cover);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final (:width, :shown) = cover.value;
    // From the page's trailing edge, so the same distance holds either way.
    const resting = PregoSpacing.xl;
    final fitsBeside = size.width - width - 2 * PregoSpacing.xl >= childSize.width;
    final settled = fitsBeside ? resting + width : (size.width - childSize.width) / 2;
    // It travels with the panel's slide whichever place it heads for, so it
    // never jumps.
    final fromEnd = resting + (settled - resting) * shown;
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
