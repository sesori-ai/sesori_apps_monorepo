import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../foundation/desktop_sidebar_layout.dart";
import "../../repositories/desktop_instance_repository.dart";

/// Owns the user layout, independently of the window's temporary compact mode.
class DesktopSidebarCubit({required final DesktopInstanceRepository repository}) extends Cubit<DesktopSidebarLayout> {
  static const double minWidth = 200;
  static const double maxWidth = 420;
  static const int maxDeferredSessions = 200;
  Future<void> _writes = Future<void>.value();

  this : super(const DesktopSidebarLayout()) {
    _writes = _restore();
  }

  Future<void> _restore() async {
    final initial = state;
    try {
      final layout = await repository.readSidebarLayout();
      // The user can drag or toggle while the initial disk read is pending.
      if (!isClosed && identical(state, initial)) {
        emit(layout.copyWith(width: layout.width.clamp(minWidth, maxWidth)));
      }
    } on Object catch (error, stackTrace) {
      logw("Failed to restore the desktop sidebar layout", error, stackTrace);
    }
  }

  /// Drag updates are memory-only; the view commits once the gesture ends.
  void resize({required double width}) {
    emit(state.copyWith(width: width.clamp(minWidth, maxWidth)));
  }

  Future<void> toggleCollapsed() {
    emit(state.copyWith(collapsed: !state.collapsed));
    return saveLayout();
  }

  Future<void> toggleProject({required String projectId}) {
    final collapsed = {...state.collapsedProjectIds};
    if (!collapsed.remove(projectId)) collapsed.add(projectId);
    emit(state.copyWith(collapsedProjectIds: collapsed));
    return saveLayout();
  }

  /// Sets [sessionId] aside at [updatedAt], its `time.updated` when the user
  /// marked it unread. An older entry is inert once the agent moves the stamp,
  /// so nothing prunes them; the cap drops the oldest.
  Future<void> deferSession({required String sessionId, required int updatedAt}) {
    final deferred = {...state.deferredSessions}
      ..remove(sessionId)
      ..[sessionId] = updatedAt;
    final overflow = deferred.length - maxDeferredSessions;
    emit(state.copyWith(deferredSessions: overflow > 0 ? Map.fromEntries(deferred.entries.skip(overflow)) : deferred));
    return saveLayout();
  }

  Future<void> resetWidth() {
    resize(width: const DesktopSidebarLayout().width);
    return saveLayout();
  }

  Future<void> saveLayout() {
    final layout = state;
    return _writes = _writes.then((_) async {
      try {
        await repository.writeSidebarLayout(layout: layout);
      } on Object catch (error, stackTrace) {
        logw("Failed to save the desktop sidebar layout", error, stackTrace);
      }
    });
  }

  @override
  Future<void> close() async {
    await super.close();
    await _writes;
  }
}
