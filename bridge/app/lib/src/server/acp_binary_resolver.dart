import "dart:io";

/// Resolves the binary used to spawn an ACP agent (`<binary> acp`).
///
/// Resolution is intentionally simple (no auto-download — ACP agents like
/// `cursor-agent` install via their own tooling):
///   1. If the flag points to an existing file, use its absolute path.
///   2. Otherwise hand the raw value to `Process.start`, which resolves it on
///      PATH.
class AcpBinaryResolver {
  AcpBinaryResolver({required this.binaryFlag});

  final String binaryFlag;

  String resolve() {
    if (binaryFlag.isEmpty) return binaryFlag;
    final file = File(binaryFlag);
    if (file.existsSync()) return file.absolute.path;
    return binaryFlag;
  }
}
