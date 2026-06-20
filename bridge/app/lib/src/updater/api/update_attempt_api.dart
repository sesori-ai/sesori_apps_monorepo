import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_shared/sesori_shared.dart';

import '../models/update_attempt.dart';

/// File-based JSON store for the single in-flight/last [UpdateAttempt].
///
/// Lives next to the managed install (`installRoot/.sesori-bridge-update-attempt.json`)
/// and mirrors the atomic tmp-write-then-rename pattern used by `UpdateCacheApi`.
class UpdateAttemptApi {
  UpdateAttemptApi({required this.installRoot});

  final String installRoot;

  static const String _fileName = '.sesori-bridge-update-attempt.json';

  String get _filePath => p.join(installRoot, _fileName);

  String get _tmpFilePath => '$_filePath.tmp';

  /// Reads the persisted attempt.
  ///
  /// Returns `null` only when no record exists. A read or parse failure is
  /// unexpected and is thrown rather than swallowed — the caller
  /// ([UpdateReconciliationService]) already catches and logs it, so failures
  /// stay observable instead of silently masquerading as "no attempt".
  Future<UpdateAttempt?> read() async {
    final File file = File(_filePath);
    if (file.existsSync()) {
      return UpdateAttempt.fromJson(jsonDecodeMap(await file.readAsString()));
    }

    // Recover from a crash in [write]'s delete→rename gap: the temp file is
    // fully flushed before the old record is deleted, so a present temp with a
    // missing target holds the latest record. Promote it into place so the
    // record survives and subsequent reads/writes/clears stay consistent.
    final File tmpFile = File(_tmpFilePath);
    if (tmpFile.existsSync()) {
      await tmpFile.rename(file.path);
      return UpdateAttempt.fromJson(jsonDecodeMap(await file.readAsString()));
    }

    return null;
  }

  Future<void> write({required UpdateAttempt attempt}) async {
    final Directory dir = Directory(installRoot);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final File tmpFile = File(_tmpFilePath);
    await tmpFile.writeAsString(jsonEncode(attempt.toJson()), flush: true);

    // tmp-write then rename-into-place. The pre-delete is required because
    // Dart's File.rename fails over an existing file on Windows (matching the
    // existing UpdateCacheApi convention). Sync existence checks satisfy the
    // project's `avoid_slow_async_io` lint.
    final File target = File(_filePath);
    if (target.existsSync()) {
      target.deleteSync();
    }
    await tmpFile.rename(target.path);
  }

  Future<void> clear() async {
    // Remove both the record and any leftover temp so a stray temp can't be
    // recovered by [read] as a resurrected record after the attempt is cleared.
    await _deleteIfExists(File(_filePath));
    await _deleteIfExists(File(_tmpFilePath));
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (file.existsSync()) {
        await file.delete();
      }
    } on FileSystemException {
      // Best-effort; a stale record is reconciled (and overwritten) next run.
    }
  }
}
