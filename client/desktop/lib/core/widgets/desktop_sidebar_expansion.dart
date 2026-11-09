import "package:flutter/foundation.dart";
import "package:material_ui/material_ui.dart";

/// Hands the sidebar's expansion animation to the panel. The animation object
/// never changes, so reading it does not rebuild anything per frame; only the
/// parts listening to the animation itself do.
class const DesktopSidebarExpansion({
  super.key,
  required final Animation<double> expansion,
  required super.child,
}) extends InheritedWidget {
  static Animation<double> of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DesktopSidebarExpansion>();
    if (scope == null) throw FlutterError("No DesktopSidebarExpansion above this sidebar.");
    return scope.expansion;
  }

  @override
  bool updateShouldNotify(DesktopSidebarExpansion oldWidget) => expansion != oldWidget.expansion;
}

/// Builds with [select] applied to [expansion], rebuilding only when that
/// result changes.
class const DesktopSidebarExpansionSelector<T>({
  super.key,
  required final Animation<double> expansion,
  required final T Function(double expansion) select,
  required final Widget Function(BuildContext context, T value) builder,
}) extends StatefulWidget {
  @override
  State<DesktopSidebarExpansionSelector<T>> createState() => _DesktopSidebarExpansionSelectorState<T>();
}

class _DesktopSidebarExpansionSelectorState<T>() extends State<DesktopSidebarExpansionSelector<T>> {
  late T _value = widget.select(widget.expansion.value);

  @override
  void initState() {
    super.initState();
    widget.expansion.addListener(_update);
  }

  @override
  void didUpdateWidget(DesktopSidebarExpansionSelector<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expansion != widget.expansion) {
      oldWidget.expansion.removeListener(_update);
      widget.expansion.addListener(_update);
    }
    _value = widget.select(widget.expansion.value);
  }

  @override
  void dispose() {
    widget.expansion.removeListener(_update);
    super.dispose();
  }

  void _update() {
    final value = widget.select(widget.expansion.value);
    if (value != _value) setState(() => _value = value);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}

/// Rebuilds [builder] with the current expansion every frame, around a [child]
/// that is built once.
class const DesktopSidebarExpansionBuilder({
  super.key,
  required final Animation<double> expansion,
  required final Widget Function(double expansion, Widget child) builder,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: expansion,
    builder: (_, child) => builder(expansion.value, child ?? const SizedBox.shrink()),
    child: child,
  );
}

/// Keeps a page's top-left corner clear for what a hidden sidebar leaves
/// there: its restore button, after the traffic lights on macOS. The room opens
/// as the sidebar slides away; outside the cockpit there is none.
class const DesktopSidebarRestoreInset({super.key, required final Widget child}) extends StatelessWidget {
  static const double buttonSize = 28;

  /// The title line's middle, down from the window's top: on macOS, the middle of
  /// the traffic lights for the window `MainFlutterWindow.swift` sets up. AppKit
  /// places them, so what shares their line follows this.
  static const double titleLineCentre = 26;

  /// Room for the product's name after the button.
  static const double _nameReach = 44;

  /// The toggle glyphs' artwork rests half a point above the middle of their box.
  static const Offset toggleGlyphNudge = Offset(0, 0.5);

  /// Where the button starts: past the traffic lights on macOS.
  static double get buttonStart => defaultTargetPlatform == TargetPlatform.macOS ? 84 : 6;

  /// What a page's top-left corner keeps clear: the button and the name.
  static double get clearance => buttonStart + buttonSize + _nameReach;

  @override
  Widget build(BuildContext context) {
    final expansion = context.dependOnInheritedWidgetOfExactType<DesktopSidebarExpansion>()?.expansion;
    if (expansion == null) return child;
    return DesktopSidebarExpansionBuilder(
      expansion: expansion,
      builder: (expansion, child) => Padding(
        padding: EdgeInsetsDirectional.only(start: clearance * (1 - expansion)),
        child: child,
      ),
      child: child,
    );
  }
}
