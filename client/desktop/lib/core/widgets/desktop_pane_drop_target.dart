import "dart:async";

import "package:desktop_drop/desktop_drop.dart";
import "package:flutter/scheduler.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:theme_prego/module_prego.dart";

/// Takes files dragged onto a whole pane and hands their paths to the
/// composer in it, which decides what each becomes.
///
/// A drop goes only to the composer that listened last, so a cross-fade that
/// briefly keeps two composers mounted never adds a file twice. A composer
/// pauses its subscription while it cannot take files (recording or
/// transcribing). With no composer ready (none listening in a read-only or
/// blocked session, or the composer paused) the pane shows no hint, and a
/// drop that lands anyway gets a notice saying why it was not added.
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
    _listenersChanged();
    listener
      ..onPause = _listenersChanged
      ..onResume = _listenersChanged
      ..onCancel = () {
        _listeners.remove(listener);
        _listenersChanged();
      };
  }

  /// Keeps a hint already showing in step with whether a composer is ready.
  /// Composers subscribe and pause while building, so the rebuild waits for
  /// the frame to finish.
  void _listenersChanged() {
    if (!_hovering) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  /// The composer a drop goes to, or null when none can take it now.
  MultiStreamController<List<String>>? get _readyListener => switch (_listeners.lastOrNull) {
    final listener? when !listener.isPaused => listener,
    _ => null,
  };

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
    if (paths.isEmpty || !_isFrontmost()) return;
    final loc = context.loc;
    switch (_listeners.lastOrNull) {
      case null:
        _showNotice(loc.desktopDropNoComposer);
      case final listener when listener.isPaused:
        _showNotice(loc.sessionDetailFinishRecordingBeforeAddingFiles);
      case final listener:
        listener.add(paths);
    }
  }

  void _showNotice(String message) => PregoPopupAlertPresenter.of(
    context,
  ).show(title: message, variant: PregoPopupAlertsNotificationsVariant.warning);

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final showsHint = _hovering && _readyListener != null;
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
