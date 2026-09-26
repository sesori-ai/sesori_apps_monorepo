import "package:material_ui/material_ui.dart";

/// How far open the sidebar is, as far as its structure cares. Rows add or
/// drop parts only when this changes; everything that moves in between reads
/// the expansion animation directly, so a frame of the animation rebuilds
/// only those few leaves instead of every row.
enum DesktopSidebarPhase() {
  rail,
  moving,
  open;

  static DesktopSidebarPhase of({required double expansion}) => switch (expansion) {
    <= 0 => rail,
    >= 1 => open,
    _ => moving,
  };
}

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

/// [DesktopSidebarExpansionSelector] over [DesktopSidebarPhase].
class const DesktopSidebarPhaseBuilder({
  super.key,
  required final Animation<double> expansion,
  required final Widget Function(BuildContext context, DesktopSidebarPhase phase) builder,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DesktopSidebarExpansionSelector(
    expansion: expansion,
    select: (expansion) => DesktopSidebarPhase.of(expansion: expansion),
    builder: builder,
  );
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

/// Clips [child] to [heightFactor] of its height, centred, and fades it with the
/// same animation: a part that folds away as the sidebar closes.
class const DesktopSidebarFold({
  super.key,
  required final Animation<double> heightFactor,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizeTransition(
    sizeFactor: heightFactor,
    alignment: Alignment.center,
    child: FadeTransition(opacity: heightFactor, child: child),
  );
}
