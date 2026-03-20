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
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor,
    builder: (sheetContext) => _ModalSafeArea(
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

  const _ModalSafeArea({required this.child});

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final viewPadding = MediaQuery.paddingOf(context);

    // When the keyboard is up its height already covers the home-indicator
    // region, so we only need the keyboard inset. When the keyboard is hidden
    // we fall back to the safe-area bottom padding.
    final bottomPadding = viewInsets.bottom > 0 ? viewInsets.bottom : viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: child,
    );
  }
}
