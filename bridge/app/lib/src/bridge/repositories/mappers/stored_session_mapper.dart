import "../../../api/database/tables/session_table.dart";
import "../models/stored_session.dart";

extension StoredSessionMapper on SessionDto {
  StoredSession toStoredSession() {
    return StoredSession(
      id: sessionId,
      backendSessionId: backendSessionId,
      pluginId: pluginId,
      projectId: projectId,
      parentSessionId: parentSessionId,
      directory: directory,
      worktreePath: worktreePath,
      branchName: branchName,
      isDedicated: isDedicated,
      archivedAt: archivedAt,
      baseBranch: baseBranch,
      baseCommit: baseCommit,
    );
  }
}
