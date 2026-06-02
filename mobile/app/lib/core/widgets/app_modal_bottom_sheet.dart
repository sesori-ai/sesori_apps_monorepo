import "package:flutter/material.dart";

/// Shows a modal bottom sheet with automatic keyboard and safe area management.
///
/// Wraps the [builder] result with bottom padding that accounts for the keyboard
/// (view insets) and the bottom safe area (e.g. home indicator on iOS). When the
/// keyboard is visible the safe-area spacer collapses automatically so that the
/// bottom inset is never counted twice.
///
/// Callers do **not** need to wrap their content in [SafeArea] or manually pad
/// for the keyboard.
///
/// Set [handleBottomSafeArea] to `false` for sheets whose content scrolls to the
/// bottom edge (e.g. a full-height list). The keyboard inset is still applied,
/// but the home-indicator inset is left for the content to consume as scroll
/// padding, so the list can scroll underneath the indicator instead of being
/// clipped above it.
// ignore: no_slop_linter/prefer_required_named_parameters, backgroundColor is intentionally optional for sheet defaults
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
  bool handleBottomSafeArea = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor,
    builder: (sheetContext) => _ModalSafeArea(
      handleBottomSafeArea: handleBottomSafeArea,
      child: builder(sheetContext),
    ),
  );
}

/// Internal widget that adds bottom padding for whichever is active — the
/// keyboard or the safe area — but never both at once.
///
/// Uses the granular [MediaQuery.viewInsetsOf] and [MediaQuery.paddingOf]
/// accessors so that the widget only rebuilds when the relevant values change.
class _ModalSafeArea extends StatelessWidget {
  final Widget child;
  final bool handleBottomSafeArea;

  const _ModalSafeArea({required this.child, this.handleBottomSafeArea = true});

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final viewPadding = MediaQuery.paddingOf(context);

    // When the keyboard is up its height already covers the home-indicator
    // region, so we only need the keyboard inset. When the keyboard is hidden
    // we fall back to the safe-area bottom padding — unless the sheet content
    // manages the bottom inset itself (handleBottomSafeArea: false), in which
    // case we leave that region for the content to fill.
    final bottomPadding = viewInsets.bottom > 0
        ? viewInsets.bottom
        : (handleBottomSafeArea ? viewPadding.bottom : 0.0);

    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: bottomPadding),
      child: child,
    );
  }
}
