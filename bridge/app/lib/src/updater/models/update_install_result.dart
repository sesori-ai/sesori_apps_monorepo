import 'package:meta/meta.dart';

import 'update_result.dart';

/// Outcome of staging an update (download → verify → extract → stage).
///
/// On success [stagingPath] points at the extracted, verified payload ready for
/// the in-place swap. On any failure [stagingPath] is `null` and [result]
/// carries the cause.
@immutable
class const UpdateInstallResult({
  required final UpdateResult result,
  required final String? stagingPath,
}) {
  const new staged({required String stagingPath}) : this(result: UpdateResult.success, stagingPath: stagingPath);

  const new failed({required UpdateResult result}) : this(result: result, stagingPath: null);
}
