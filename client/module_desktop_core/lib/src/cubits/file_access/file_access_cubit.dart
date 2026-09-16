import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../foundation/platform/file_access_permission.dart";
import "../../foundation/platform/window_host.dart";

import "file_access_state.dart";

/// One application-run presentation owner; no persisted permission or dismissal.
class FileAccessCubit({required final FileAccessPermission permission, required final WindowHost windowHost})
    extends Cubit<FileAccessState> {
  late final StreamSubscription<WindowHostState> _subscription;
  int _checkGeneration = 0;

  this : super(const FileAccessState(status: FileAccessStatus.unknown, dismissed: false)) {
    _subscription = windowHost.states.listen((event) {
      if (event == WindowHostState.focused) unawaited(refresh());
    });
    unawaited(refresh());
  }

  Future<void> refresh() async {
    final generation = ++_checkGeneration;
    FileAccessStatus status;
    try {
      status = await permission.check();
    } on Object catch (error, stackTrace) {
      logw("Failed to check desktop file access", error, stackTrace);
      status = FileAccessStatus.unknown;
    }
    if (isClosed || generation != _checkGeneration) return;
    emit(FileAccessState(status: status, dismissed: state.dismissed));
  }

  void dismiss() => emit(FileAccessState(status: state.status, dismissed: true));

  Future<void> openSystemSettings() async {
    try {
      await permission.openSystemSettings();
    } on Object catch (error, stackTrace) {
      logw("Failed to open desktop file-access settings", error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    _checkGeneration++;
    await _subscription.cancel();
    await super.close();
  }
}
