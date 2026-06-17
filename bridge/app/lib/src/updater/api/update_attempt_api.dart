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

  /// Reads the persisted attempt.
  ///
  /// Returns `null` only when no record exists. A read or parse failure is
  /// unexpected and is thrown rather than swallowed — the caller
  /// ([UpdateReconciliationService]) already catches and logs it, so failures
  /// stay observable instead of silently masquerading as "no attempt".
  Future<UpdateAttempt?> read() async {
    final File file = File(_filePath);
    if (!file.existsSync()) {
      return null;
    }

    final String contents = await file.readAsString();
    return UpdateAttempt.fromJson(jsonDecodeMap(contents));
  }

  Future<void> write({required UpdateAttempt attempt}) async {
    final Directory dir = Directory(installRoot);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final File tmpFile = File('$_filePath.tmp');
    await tmpFile.writeAsString(jsonEncode(attempt.toJson()), flush: true);

    final File target = File(_filePath);
    if (target.existsSync()) {
      await target.delete();
    }
    await tmpFile.rename(target.path);
  }

  Future<void> clear() async {
    final File file = File(_filePath);
    try {
      if (file.existsSync()) {
        await file.delete();
      }
    } on FileSystemException {
      // Best-effort; a stale record is reconciled (and overwritten) next run.
    }
  }
}
