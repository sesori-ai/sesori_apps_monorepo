class CodexThreadRecord {
  const CodexThreadRecord({
    required this.id,
    required this.name,
    required this.directory,
    required this.createdAt,
    required this.updatedAt,
    required this.model,
    required this.modelProvider,
  });

  final String id;
  final String? name;
  final String? directory;
  final int? createdAt;
  final int? updatedAt;
  final String? model;
  final String? modelProvider;
}
