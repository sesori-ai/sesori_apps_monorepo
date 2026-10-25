import "dart:ffi";

import "package:ffi/ffi.dart";

/// `vpkc_asset_t`: one release package.
final class VelopackAsset() extends Struct {
  external Pointer<Utf8> packageId;
  external Pointer<Utf8> version;
  external Pointer<Utf8> type;
  external Pointer<Utf8> fileName;
  external Pointer<Utf8> sha1;
  external Pointer<Utf8> sha256;
  @Uint64()
  external int size;
  external Pointer<Utf8> notesMarkdown;
  external Pointer<Utf8> notesHtml;
}

/// `vpkc_update_info_t`: what a check found.
final class VelopackUpdateInfo() extends Struct {
  external Pointer<VelopackAsset> targetFullRelease;
  external Pointer<VelopackAsset> baseRelease;
  external Pointer<Pointer<VelopackAsset>> deltasToTarget;
  @Size()
  external int deltasToTargetCount;
  @Bool()
  external bool isDowngrade;
}

/// A Velopack call failed; [message] is the library's last error.
final class const VelopackException({required final String operation, required final String message}) implements Exception {
  @override
  String toString() => "Velopack could not $operation: $message";
}

/// Layer-0 hand-written `dart:ffi` bindings to the functions this app uses from
/// the bundled Velopack 1.2.161 C library (`Velopack.h`).
///
/// Threading: every function runs synchronously on the calling thread and the
/// app passes no callbacks, so Velopack never calls back into Dart from any
/// thread. The startup hooks run on the root isolate before the first frame,
/// as Velopack requires. Every update-manager call blocks on disk work, so
/// `VelopackPackagesStorage` makes them from a short-lived background isolate.
/// The last error is process-global; it is read right after the failed call.
final class VelopackBindings._create({required final DynamicLibrary _library}) {
  new open({required String libraryPath}) : this._create(library: DynamicLibrary.open(libraryPath));

  static const int updateError = -1;
  static const int updateAvailable = 0;
  static const int noUpdateAvailable = 1;
  static const int remoteIsEmpty = 2;

  late final void Function(bool autoApply) _setAutoApplyOnStartup = _library
      .lookupFunction<Void Function(Bool), void Function(bool)>("vpkc_app_set_auto_apply_on_startup");

  late final void Function(Pointer<Void> userData) _appRun = _library
      .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>("vpkc_app_run");

  late final int Function(Pointer<Utf8> error, int capacity) _getLastError = _library
      .lookupFunction<Size Function(Pointer<Utf8>, Size), int Function(Pointer<Utf8>, int)>("vpkc_get_last_error");

  /// A local path makes Velopack read that directory as a file source.
  late final bool Function(
    Pointer<Utf8> urlOrPath,
    Pointer<Void> options,
    Pointer<Void> locator,
    Pointer<Pointer<Void>> manager,
  )
  newUpdateManager = _library
      .lookupFunction<
        Bool Function(Pointer<Utf8>, Pointer<Void>, Pointer<Void>, Pointer<Pointer<Void>>),
        bool Function(Pointer<Utf8>, Pointer<Void>, Pointer<Void>, Pointer<Pointer<Void>>)
      >("vpkc_new_update_manager");

  late final void Function(Pointer<Void> manager) freeUpdateManager = _library
      .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>("vpkc_free_update_manager");

  /// The newest downloaded full package newer than the running version.
  late final bool Function(Pointer<Void> manager, Pointer<Pointer<VelopackAsset>> asset) updatePendingRestart = _library
      .lookupFunction<
        Bool Function(Pointer<Void>, Pointer<Pointer<VelopackAsset>>),
        bool Function(Pointer<Void>, Pointer<Pointer<VelopackAsset>>)
      >("vpkc_update_pending_restart");

  /// Returns one of [updateError], [updateAvailable], [noUpdateAvailable] or [remoteIsEmpty].
  late final int Function(Pointer<Void> manager, Pointer<Pointer<VelopackUpdateInfo>> update) checkForUpdates = _library
      .lookupFunction<
        Int8 Function(Pointer<Void>, Pointer<Pointer<VelopackUpdateInfo>>),
        int Function(Pointer<Void>, Pointer<Pointer<VelopackUpdateInfo>>)
      >("vpkc_check_for_updates");

  /// Copies the package from the source into Velopack's packages directory and
  /// refuses it unless its size and SHA-256 match the checked feed. The
  /// progress callback is always null: no callback, no extra thread.
  late final bool Function(
    Pointer<Void> manager,
    Pointer<VelopackUpdateInfo> update,
    Pointer<Void> progressCallback,
    Pointer<Void> userData,
  )
  downloadUpdates = _library
      .lookupFunction<
        Bool Function(Pointer<Void>, Pointer<VelopackUpdateInfo>, Pointer<Void>, Pointer<Void>),
        bool Function(Pointer<Void>, Pointer<VelopackUpdateInfo>, Pointer<Void>, Pointer<Void>)
      >("vpkc_download_updates");

  /// Starts the updater, which waits for this process to exit before applying
  /// the package, and returns without waiting for it.
  late final bool Function(
    Pointer<Void> manager,
    Pointer<VelopackAsset> asset,
    bool silent,
    bool restart,
    Pointer<Pointer<Utf8>> restartArgs,
    int restartArgCount,
  )
  waitExitThenApplyUpdates = _library
      .lookupFunction<
        Bool Function(Pointer<Void>, Pointer<VelopackAsset>, Bool, Bool, Pointer<Pointer<Utf8>>, Size),
        bool Function(Pointer<Void>, Pointer<VelopackAsset>, bool, bool, Pointer<Pointer<Utf8>>, int)
      >("vpkc_wait_exit_then_apply_updates");

  late final void Function(Pointer<VelopackUpdateInfo> update) freeUpdateInfo = _library
      .lookupFunction<Void Function(Pointer<VelopackUpdateInfo>), void Function(Pointer<VelopackUpdateInfo>)>(
        "vpkc_free_update_info",
      );

  late final void Function(Pointer<VelopackAsset> asset) freeAsset = _library
      .lookupFunction<Void Function(Pointer<VelopackAsset>), void Function(Pointer<VelopackAsset>)>("vpkc_free_asset");

  /// Velopack's app startup: it would answer hook launches (the Windows runner
  /// answers them first) and cleans up old packages. Auto-apply is off: a second
  /// launch while the primary holds a downloaded update would otherwise start
  /// the updater, which stops the running primary. Updates apply on exit.
  void runStartupHooks() {
    _setAutoApplyOnStartup(false);
    _appRun(nullptr);
  }

  VelopackException failure({required String operation}) => using((Arena arena) {
    const int capacity = 4096;
    // The library writes its terminator one byte past the copied capacity.
    final Pointer<Utf8> buffer = arena.allocate<Utf8>(capacity + 1);
    _getLastError(buffer, capacity);
    return VelopackException(operation: operation, message: buffer.toDartString());
  });
}
