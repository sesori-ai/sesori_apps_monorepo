sealed class WorktreeSafetyResult();

class WorktreeSafe() extends WorktreeSafetyResult;

class WorktreeUnsafe({required this.issues}) extends WorktreeSafetyResult {
  final List<SafetyIssue> issues;
}

sealed class SafetyIssue();

class UnstagedChanges() extends SafetyIssue;

class BranchMismatch({required this.expected, required this.actual}) extends SafetyIssue {
  final String expected;
  final String actual;
}

sealed class WorktreeResult();

class WorktreeSuccess({
    required this.path,
    required this.branchName,
    required this.baseBranch,
    required this.baseCommit,
  }) extends WorktreeResult {
  final String path;
  final String branchName;
  final String baseBranch;
  final String baseCommit;
}

class WorktreeFallback({required this.originalPath, required this.reason}) extends WorktreeResult {
  final String originalPath;
  final String reason;
}
