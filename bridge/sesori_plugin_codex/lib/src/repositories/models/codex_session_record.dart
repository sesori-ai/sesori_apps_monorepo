class CodexSessionRecord {
  const CodexSessionRecord({
    required this.id,
    required this.rolloutPath,
    required this.cwd,
    required this.threadName,
    required this.createdAt,
    required this.updatedAt,
    required this.cliVersion,
    required this.modelProvider,
    required this.model,
  });

  final String id;
  final String rolloutPath;
  final String? cwd;
  final String? threadName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? cliVersion;
  final String? modelProvider;
  final String? model;
}
