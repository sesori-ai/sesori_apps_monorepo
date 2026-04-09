import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../repositories/opencode_db_repository.dart";

/// Opportunistically enables `auto_vacuum = FULL` on the OpenCode SQLite
/// database during bridge startup.
///
/// This is a one-time conversion. Once the database header is updated, all
/// future DELETE operations by OpenCode automatically reclaim disk space.
/// If the database is in use, the operation is silently skipped and retried
/// on the next bridge startup.
class OpenCodeDbMaintenanceService {
  /// Conservative estimate of VACUUM throughput on modern SSDs (MB/s).
  static const _estimatedVacuumMbPerSecond = 75;

  final OpenCodeDbRepository _repository;

  OpenCodeDbMaintenanceService({required OpenCodeDbRepository repository}) : _repository = repository;

  /// Checks whether the OpenCode database needs auto-vacuum enabled,
  /// and if so, attempts to enable it.
  ///
  /// This method never throws — all errors are handled by the repository.
  void optimizeIfNeeded({required String dbPath}) {
    final mode = _repository.getAutoVacuumMode(dbPath: dbPath);
    if (mode == null) return;
    if (mode != 0) {
      Log.d(
        "[DbMaintenance] auto_vacuum already enabled (mode=$mode) — skipping",
      );
      return;
    }

    final sizeBytes = _repository.getDbSizeBytes(dbPath: dbPath);
    final sizeMB = sizeBytes / (1024 * 1024);
    final estimatedSeconds = (sizeMB / _estimatedVacuumMbPerSecond).ceil().clamp(1, 600);

    Log.i(
      "[DbMaintenance] OpenCode database found "
      "(${sizeMB.toStringAsFixed(0)} MB). "
      "Enabling auto-vacuum — estimated duration: "
      "~${_formatDuration(estimatedSeconds)}",
    );

    final result = _repository.enableAutoVacuumAndVacuum(dbPath: dbPath);
    if (result == null) return;

    final (sizeBefore, sizeAfter) = result;
    final savedMB = (sizeBefore - sizeAfter) / (1024 * 1024);

    Log.i(
      "[DbMaintenance] Auto-vacuum enabled successfully. "
      "Reclaimed ${savedMB.toStringAsFixed(0)} MB "
      "(${(sizeAfter / (1024 * 1024)).toStringAsFixed(0)} MB remaining)",
    );
  }

  static String _formatDuration(int seconds) {
    if (seconds < 60) return "$seconds seconds";
    final minutes = (seconds / 60).ceil();
    return "$minutes minute${minutes > 1 ? "s" : ""}";
  }
}
