import "package:material_ui/material_ui.dart";

/// What a product shell draws over the top-start corner of the routes below
/// it, such as the macOS traffic lights over a desktop window whose content
/// runs under its hidden title bar. A route that draws its own top bar passes
/// the bar's row through [clear], so its leading control stays out from under
/// them. Phones provide none: their bars follow the safe area alone.
class const TopBarLeadingClearance({
  super.key,

  /// Wraps a top bar's row so it starts past what the shell draws there. Pass
  /// a tear-off, so a rebuild with the same one notifies nobody.
  required final Widget Function({required Widget child}) wrap,
  required super.child,
}) extends InheritedWidget {
  /// [child] cleared for the nearest shell's corner, or unchanged under none.
  static Widget clear({required BuildContext context, required Widget child}) {
    final scope = context.dependOnInheritedWidgetOfExactType<TopBarLeadingClearance>();
    return scope == null ? child : scope.wrap(child: child);
  }

  /// [child] with no clearance, for a top bar that sits below the corner, such
  /// as a panel's that floats lower in the window.
  static Widget remove({required Widget child}) => TopBarLeadingClearance(wrap: _unchanged, child: child);

  static Widget _unchanged({required Widget child}) => child;

  @override
  bool updateShouldNotify(TopBarLeadingClearance oldWidget) => wrap != oldWidget.wrap;
}
