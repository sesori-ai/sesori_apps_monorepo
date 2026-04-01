class BaseBranchUnreachableException implements Exception {
  final String message;

  const BaseBranchUnreachableException({required this.message});

  @override
  String toString() => message;
}

class GitDiffQueryException implements Exception {
  final String message;

  const GitDiffQueryException({required this.message});

  @override
  String toString() => message;
}
