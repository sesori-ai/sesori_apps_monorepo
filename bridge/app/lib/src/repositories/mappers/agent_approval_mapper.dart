import "package:sesori_shared/sesori_shared.dart" show PendingPermission;

import "../models/agent_approval.dart";
import "../models/scheduled_task_agent_change.dart";

extension AgentApprovalMapper on AgentApproval {
  /// The permission request the app shows. "Always" is hidden: every change
  /// needs its own Allow.
  PendingPermission toPendingPermission() {
    return PendingPermission(
      id: requestId,
      sessionID: sessionId,
      displaySessionId: displaySessionId,
      tool: switch (change) {
        SetTaskEnabledChange(enabled: true) => "Sesori: resume task",
        SetTaskEnabledChange(enabled: false) => "Sesori: pause task",
        RunTaskNowChange() => "Sesori: run task now",
      },
      description: description,
      allowAlways: false,
    );
  }
}
