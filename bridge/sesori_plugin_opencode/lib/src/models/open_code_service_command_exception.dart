/// An OpenCode CLI command that failed, timed out or printed something
/// unexpected. [cause] keeps the original error or the exit code's output.
class const OpenCodeServiceCommandException({required final String message, required final Object? cause})
    implements Exception {
  @override
  String toString() => "OpenCodeServiceCommandException: $message";
}
