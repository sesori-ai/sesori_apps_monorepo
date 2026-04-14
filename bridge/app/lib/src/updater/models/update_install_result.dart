import 'package:meta/meta.dart';

import 'pending_windows_update.dart';
import 'update_result.dart';

@immutable
class UpdateInstallResult {
  final UpdateResult result;
  final PendingWindowsUpdate? pendingWindowsUpdate;

  const UpdateInstallResult({
    required this.result,
    required this.pendingWindowsUpdate,
  });

  const UpdateInstallResult.completed({required UpdateResult result})
    : this(result: result, pendingWindowsUpdate: null);

  const UpdateInstallResult.pending({required PendingWindowsUpdate pendingWindowsUpdate})
    : this(
        result: UpdateResult.success,
        pendingWindowsUpdate: pendingWindowsUpdate,
      );
}
