import 'package:meta/meta.dart';

import 'update_result.dart';

/// Outcome of staging an update (download → verify → extract → stage).
///
/// On success [stagingPath] points at the extracted, verified payload ready for
/// the in-place swap. On any failure [stagingPath] is `null` and [result]
/// carries the cause.
@immutable
class UpdateInstallResult {
  final UpdateResult result;
  final String? stagingPath;

  const UpdateInstallResult({
    required this.result,
    required this.stagingPath,
  });

  const UpdateInstallResult.staged({required String stagingPath})
    : this(result: UpdateResult.success, stagingPath: stagingPath);

  const UpdateInstallResult.failed({required UpdateResult result}) : this(result: result, stagingPath: null);
}
