sealed class WorktreeSafetyResult();

class WorktreeSafe() extends WorktreeSafetyResult;

class WorktreeUnsafe({required final List<SafetyIssue> issues}) extends WorktreeSafetyResult;

sealed class SafetyIssue();

class UnstagedChanges() extends SafetyIssue;

class CommitsOnNoBranch() extends SafetyIssue;

sealed class WorktreeResult();

class WorktreeSuccess({
  required final String path,
  required final String baseBranch,
  required final String baseCommit,
}) extends WorktreeResult;

class WorktreeFallback({required final String originalPath, required final String reason}) extends WorktreeResult;

/// What recreating a removed worktree at its old path did.
sealed class WorktreeRecreation();

class WorktreeRecreated() extends WorktreeRecreation;

/// The branch the worktree was on is gone, or it kept none (a detached HEAD),
/// and recreating from the base was not asked for.
class WorktreeRecreationBranchMissing() extends WorktreeRecreation;

/// Git could not add the worktree, or there is no base to start it from.
class WorktreeRecreationFailed() extends WorktreeRecreation;
