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
  /// Returns `null` only when no record exists. A parse failure of the committed
  /// record is unexpected and is thrown rather than swallowed — the caller
  /// ([UpdateReconciliationService]) already catches and logs it, so failures
  /// stay observable instead of silently masquerading as "no attempt".
  Future<UpdateAttempt?> read() async {
    final File target = File(_filePath);
    final File tmp = File(_tmpFilePath);

    // A surviving temp is always the newest write: [write] flushes the temp,
    // then deletes the old target, then renames the temp into place, and a
    // successful write always consumes the temp. So if the temp exists — whether
    // or not the (stale) target also survives a crash mid-write — it holds the
    // latest record. Prefer it when it parses, and promote it into place. A temp
    // that doesn't parse is a partial write: discard it and fall back to the
    // last committed target rather than resurrecting garbage.
    if (tmp.existsSync()) {
      final UpdateAttempt? recovered = _tryParse(await tmp.readAsString());
      if (recovered != null) {
        if (target.existsSync()) {
          target.deleteSync();
        }
        await tmp.rename(target.path);
        return recovered;
      }
      await _deleteIfExists(tmp);
    }

    if (target.existsSync()) {
      return UpdateAttempt.fromJson(jsonDecodeMap(await target.readAsString()));
    }

    return null;
  }

  UpdateAttempt? _tryParse(String contents) {
    try {
      return UpdateAttempt.fromJson(jsonDecodeMap(contents));
    } on Object {
      return null;
    }
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
