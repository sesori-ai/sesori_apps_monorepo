sealed class WorktreeSafetyResult();

class WorktreeSafe() extends WorktreeSafetyResult;

class WorktreeUnsafe({required final List<SafetyIssue> issues}) extends WorktreeSafetyResult;

sealed class SafetyIssue();

class UnstagedChanges() extends SafetyIssue;

sealed class WorktreeResult();

class WorktreeSuccess({
  required final String path,
  required final String branchName,
  required final String baseBranch,
  required final String baseCommit,
}) extends WorktreeResult;

class WorktreeFallback({required final String originalPath, required final String reason}) extends WorktreeResult;
