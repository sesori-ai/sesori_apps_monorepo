import "package:material_ui/material_ui.dart";

/// What the reader drives the app with.
enum PregoInteractionMode() {
  /// A finger: roomy rows, long-press menus that lift their row.
  touch,

  /// A mouse: compact rows, menus that open where the click landed.
  pointer,
}

/// Selects the presentation of shared widgets for the input a shell is built
/// for, including their spacing and sizes. A product shell built for a mouse
/// installs one scope at its root, and a touch shell installs none.
///
/// It carries only the mode, not spacing or theme values. Shared widgets don't
/// read it inline: a desktop difference lives in metrics, in a behaviour wrapper
/// in this folder, or in a desktop variant of the component. The
/// `avoid_interaction_mode_reads` lint reports any other read, and a read not
/// yet moved carries an ignore naming its home (`pending: <home>`). What a
/// product does differently, rather than how a widget is drawn, comes through
/// constructor parameters from the shell.
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
