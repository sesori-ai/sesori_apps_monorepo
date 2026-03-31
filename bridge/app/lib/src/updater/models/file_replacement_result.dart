import 'pending_windows_update.dart';

class FileReplacementResult {
  final bool success;
  final PendingWindowsUpdate? pendingWindowsUpdate;

  const FileReplacementResult._({
    required this.success,
    required this.pendingWindowsUpdate,
  });

  const FileReplacementResult.success()
    : this._(
        success: true,
        pendingWindowsUpdate: null,
      );

  const FileReplacementResult.failure()
    : this._(
        success: false,
        pendingWindowsUpdate: null,
      );

  const FileReplacementResult.pending({required PendingWindowsUpdate pending})
    : this._(
        success: true,
        pendingWindowsUpdate: pending,
      );
}
