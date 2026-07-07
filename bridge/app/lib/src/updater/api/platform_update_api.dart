import 'dart:io';

import '../../bridge/foundation/process_runner.dart';
import 'posix_update_api.dart';
import 'windows_update_api.dart';

/// OS-specific, in-place swap of the managed binary + `lib/` from a staged
/// payload into the live install root, performed while the bridge is running.
///
/// The running process keeps executing its in-memory image and memory-mapped
/// libraries; the swapped on-disk files take effect on the next launch. Each
/// implementation is responsible for rolling back a partial swap so a failure
/// never leaves a half-updated install, and for sweeping the residue it leaves
/// behind (the displaced old artifacts that can only be deleted on a later
/// run).
abstract class PlatformUpdateApi {
  /// Swaps the staged binary + `lib/` at [stagingPath] into [installRoot] in
  /// place. Throws on failure, after rolling back any partial swap.
  Future<void> applyInPlace({required String installRoot, required String stagingPath});

  /// Best-effort deletion of leftover backup artifacts (`.old`/`.rollback`)
  /// from a previous apply. Safe to call when nothing remains.
  Future<void> sweepResidue({required String installRoot});

  /// Whether a second in-place apply can safely run in the same session before
  /// the swapped binary is activated by a restart.
  ///
  /// POSIX can unlink the displaced backup of a still-running binary, so each
  /// apply starts from a clean backup slot and chaining is safe. Windows cannot
  /// delete the loaded `.old` backup until the next launch, so a second apply
  /// would collide with the locked backup and fail — it must wait for a restart.
  bool get supportsInSessionChaining;

  /// Returns the implementation matching the host platform.
  factory PlatformUpdateApi.forPlatform({required ProcessRunner processRunner}) {
    if (Platform.isWindows) {
      return const WindowsUpdateApi();
    }
    return PosixUpdateApi(processRunner: processRunner);
  }
}

/// Raised when an in-place swap cannot be completed. The applier rolls back any
/// partial state before throwing so the running install is left intact.
class UpdateApplyException implements Exception {
  const UpdateApplyException(this.message);

  final String message;

  @override
  String toString() => 'UpdateApplyException: $message';
}
