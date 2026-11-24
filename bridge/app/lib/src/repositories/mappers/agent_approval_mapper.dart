import "package:sesori_shared/sesori_shared.dart" show PendingPermission;

import "../models/agent_approval.dart";
import "../models/agent_approval_change.dart";

extension AgentApprovalMapper on AgentApproval {
  /// The permission request the app shows. "Always" is hidden: every change
  /// needs its own Allow.
  PendingPermission toPendingPermission() {
    return PendingPermission(
      id: requestId,
      sessionID: sessionId,
      displaySessionId: displaySessionId,
      tool: switch (change) {
        CreateTaskChange() => "Sesori: create task",
        UpdateTaskChange() => "Sesori: update task",
        SetTaskEnabledChange(enabled: true) => "Sesori: resume task",
        SetTaskEnabledChange(enabled: false) => "Sesori: pause task",
        RunTaskNowChange() => "Sesori: run task now",
        ScheduleCommandWakeUp() => "Sesori: wake-up command",
        ConfirmByModeCommand() => "Sesori: run wake-up command",
        ToolGroupAgentChange(:final title) => title,
      },
      description: description,
      allowAlways: false,
    );
  }
}
