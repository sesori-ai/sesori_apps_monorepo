import "dart:io";

/// Classifies a [FileSystemException] as an operating-system permission
/// denial.
///
/// On macOS, directories such as `~/Desktop`, `~/Documents`, `~/Downloads`,
/// and external/iCloud volumes are gated behind TCC ("Full Disk Access"). When
/// the terminal running the bridge has not been granted access, `dart:io`
/// filesystem calls fail with `EPERM`/`EACCES`. This validator recognises those
/// denials so callers can surface an actionable message instead of a generic
/// I/O error.
class FilesystemPermissionValidator {
  const FilesystemPermissionValidator();

  /// `errno` for "operation not permitted" — the typical macOS TCC denial.
  static const int _ePerm = 1;

  /// `errno` for "permission denied".
  static const int _eAcces = 13;

  /// Returns `true` when [error] is an OS-level permission denial.
  bool isPermissionDenied(FileSystemException error) {
    final int? code = error.osError?.errorCode;
    if (code == _ePerm || code == _eAcces) {
      return true;
    }
    final String message = "${error.osError?.message ?? ''} ${error.message}".toLowerCase();
    return message.contains("permission denied") ||
        message.contains("operation not permitted") ||
        message.contains("access is denied");
  }
}
