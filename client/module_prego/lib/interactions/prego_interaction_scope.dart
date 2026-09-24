import "package:material_ui/material_ui.dart";

/// What the reader drives the app with.
enum PregoInteractionMode() {
  /// A finger: roomy rows, long-press menus that lift their row.
  touch,

  /// A mouse: compact rows, menus that open where the click landed.
  pointer,
}

/// Tells the few shared widgets with an agreed pointer presentation which one
/// to draw. A product shell built for a mouse installs one scope at its root.
///
/// This is not a density system: it carries no spacing and no theme values, and
/// a widget reads it in one place.
class const PregoInteractionScope({
  super.key,
  required final PregoInteractionMode mode,
  required super.child,
}) extends InheritedWidget {
  /// The mode in force at [context]: [PregoInteractionMode.touch] where no
  /// scope exists, so a touch shell installs nothing.
  static PregoInteractionMode of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PregoInteractionScope>()?.mode ?? PregoInteractionMode.touch;

  @override
  bool updateShouldNotify(PregoInteractionScope oldWidget) => mode != oldWidget.mode;
}
