import "package:sesori_bridge/src/services/worktree_service.dart";

class DeletionWorktreeServiceFake({final List<String>? operationLog}) implements WorktreeService {
  WorktreeSafetyResult safetyResult = WorktreeSafe();
  bool removeResult = true;

  int checkCallCount = 0;
  int removeCallCount = 0;

  String? lastCheckWorktreePath;
  String? lastCheckBaseCommit;
  String? lastRemoveProjectId;
  String? lastRemoveWorktreePath;
  bool? lastRemoveForce;

  /// The branch [keepWorktreeHead] reports, or the error it throws.
  String? keptBranch;
  Object? keepError;
  final keptHeads = <String>[];
  final releasedHeads = <String>[];

  @override
  Future<WorktreeSafetyResult> checkWorktreeSafety({required String worktreePath, required String? baseCommit}) async {
    checkCallCount++;
    operationLog?.add("checkSafety");
    lastCheckWorktreePath = worktreePath;
    lastCheckBaseCommit = baseCommit;
    return safetyResult;
  }

  @override
  Future<bool> removeWorktree({
    required String pluginId,
    required String projectId,
    required String worktreePath,
    required bool force,
  }) async {
    removeCallCount++;
    operationLog?.add("removeWorktree");
    lastRemoveProjectId = projectId;
    lastRemoveWorktreePath = worktreePath;
    lastRemoveForce = force;
    return removeResult;
  }

  @override
  Future<String?> keepWorktreeHead({required String projectId, required String worktreePath}) async {
    operationLog?.add("keepHead");
    keptHeads.add(worktreePath);
    if (keepError case final error?) throw error;
    return keptBranch;
  }

  @override
  Future<void> releaseWorktreeHead({required String projectId, required String worktreePath}) async {
    operationLog?.add("releaseHead");
    releasedHeads.add(worktreePath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
