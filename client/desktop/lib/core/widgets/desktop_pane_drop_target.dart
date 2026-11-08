import "dart:async";

import "package:desktop_drop/desktop_drop.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:theme_prego/module_prego.dart";

/// Takes files dragged onto a whole pane and hands their paths to the
/// composer in it, which decides what each becomes.
///
/// A drop goes only to the composer that listened last, so a cross-fade that
/// briefly keeps two composers mounted never adds a file twice. With no
/// composer listening (a read-only or blocked session) the pane shows no hint,
/// so a drop it then ignores was never offered.
class const DesktopPaneDropTarget({
  super.key,
  required final Widget child,
}) extends StatefulWidget {
  /// The paths dropped on the nearest pane, or null outside one.
  static Stream<List<String>>? droppedPathsOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DroppedPathsScope>()?.droppedPaths;

  @override
  State<DesktopPaneDropTarget> createState() => _DesktopPaneDropTargetState();
}

class _DesktopPaneDropTargetState() extends State<DesktopPaneDropTarget> {
  static const _fade = Duration(milliseconds: 150);

  final _listeners = <MultiStreamController<List<String>>>[];
  late final Stream<List<String>> _droppedPaths = Stream.multi(_listen);
  bool _hovering = false;

  void _listen(MultiStreamController<List<String>> listener) {
    _listeners.add(listener);
    listener.onCancel = () => _listeners.remove(listener);
  }

  /// Every mounted target hears every drop inside its bounds, so a pane under
  /// a pushed page, or under a dialog on an outer navigator, takes none.
  bool _isFrontmost() {
    BuildContext? current = context;
    while (current != null) {
      if (ModalRoute.isCurrentOf(current) == false) return false;
      current = current.findAncestorStateOfType<NavigatorState>()?.context;
    }
    return true;
  }

  void _setHovering(bool hovering) {
    if (hovering != _hovering) setState(() => _hovering = hovering);
  }

  @override
  void dispose() {
    for (final listener in [..._listeners]) {
      listener.closeSync();
    }
    super.dispose();
  }

  void _handleDrop(DropDoneDetails details) {
    _setHovering(false);
    final paths = [
      for (final item in details.files)
        if ((item is DropItemFile || item is DropItemDirectory) && item.path.isNotEmpty) item.path,
    ];
    if (paths.isEmpty || _listeners.isEmpty || !_isFrontmost()) return;
    _listeners.last.add(paths);
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    // ponytail: listening is read when the drag enters, not tracked live; a
    // composer that appears mid-drag shows the hint from the next drag on.
    final showsHint = _hovering && _listeners.isNotEmpty;
    return DropTarget(
      onDragEntered: (_) => _setHovering(_isFrontmost()),
      onDragExited: (_) => _setHovering(false),
      onDragDone: _handleDrop,
      child: _DroppedPathsScope(
        droppedPaths: _droppedPaths,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: showsHint ? 1 : 0,
                  duration: prefersReducedMotion(context) ? Duration.zero : _fade,
                  child: ColoredBox(
                    color: prego.colors.bgSurface1.withValues(alpha: 0.88),
                    child: Center(
                      child: Text(
                        context.loc.desktopDropFilesHint,
                        style: prego.textTheme.textMd.medium.copyWith(color: prego.colors.textPrimary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class const _DroppedPathsScope({
  required final Stream<List<String>> droppedPaths,
  required super.child,
}) extends InheritedWidget {
  @override
  bool updateShouldNotify(_DroppedPathsScope oldWidget) => droppedPaths != oldWidget.droppedPaths;
}
