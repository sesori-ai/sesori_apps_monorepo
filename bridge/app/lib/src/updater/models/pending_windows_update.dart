class PendingWindowsUpdate {
  final String installRoot;
  final String stagingPath;
  final String archivePath;
  final String lockPath;

  const PendingWindowsUpdate({
    required this.installRoot,
    required this.stagingPath,
    required this.archivePath,
    required this.lockPath,
  });
}
