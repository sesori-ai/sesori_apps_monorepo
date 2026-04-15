sealed class WorktreeSafetyResult {}

class WorktreeSafe extends WorktreeSafetyResult {}

class WorktreeUnsafe extends WorktreeSafetyResult {
  final List<SafetyIssue> issues;
  WorktreeUnsafe({required this.issues});
}

sealed class SafetyIssue {}

class UnstagedChanges extends SafetyIssue {}

class BranchMismatch extends SafetyIssue {
  final String expected;
  final String actual;
  BranchMismatch({required this.expected, required this.actual});
}

sealed class WorktreeResult {}

class WorktreeSuccess extends WorktreeResult {
  final String path;
  final String branchName;
  final String baseBranch;
  final String baseCommit;
  final bool isDedicated;

  WorktreeSuccess({
    required this.path,
    required this.branchName,
    required this.baseBranch,
    required this.baseCommit,
    required this.isDedicated,
  });
}

class WorktreeFallback extends WorktreeResult {
  final String originalPath;
  final String reason;

  WorktreeFallback({required this.originalPath, required this.reason});
}
