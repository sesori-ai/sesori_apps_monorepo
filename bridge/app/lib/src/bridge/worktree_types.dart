sealed class WorktreeSafetyResult {
  String? get activeBranch;
}

class WorktreeSafe extends WorktreeSafetyResult {
  @override
  final String? activeBranch;

  WorktreeSafe({this.activeBranch});
}

class WorktreeUnsafe extends WorktreeSafetyResult {
  final List<SafetyIssue> issues;
  @override
  final String? activeBranch;

  WorktreeUnsafe({required this.issues, this.activeBranch});
}

sealed class SafetyIssue;

class UnstagedChanges extends SafetyIssue;

sealed class WorktreeResult;

class WorktreeSuccess extends WorktreeResult {
  final String path;
  final String branchName;
  final String baseBranch;
  final String baseCommit;

  WorktreeSuccess({
    required this.path,
    required this.branchName,
    required this.baseBranch,
    required this.baseCommit,
  });
}

class WorktreeFallback extends WorktreeResult {
  final String originalPath;
  final String reason;

  WorktreeFallback({required this.originalPath, required this.reason});
}
