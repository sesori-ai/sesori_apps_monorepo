import "package:sesori_bridge/src/services/worktree_service.dart";

class DeletionWorktreeServiceFake({final List<String>? operationLog}) implements WorktreeService {
  WorktreeSafetyResult safetyResult = WorktreeSafe();
  bool removeResult = true;
  bool branchExistsResult = true;

  int checkCallCount = 0;
  int removeCallCount = 0;

  String? lastCheckWorktreePath;
  String? lastRemoveProjectId;
  String? lastRemoveWorktreePath;
  bool? lastRemoveForce;

  @override
  Future<WorktreeSafetyResult> checkWorktreeSafety({required String worktreePath}) async {
    checkCallCount++;
    operationLog?.add("checkSafety");
    lastCheckWorktreePath = worktreePath;
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
  Future<bool> branchExists({required String projectId, required String branchName}) async => branchExistsResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
