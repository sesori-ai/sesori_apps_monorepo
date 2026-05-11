import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "codex_app_server_client.dart";

/// Translates `codex app-server` `ServerNotification` frames into
/// bridge-neutral [BridgeSseEvent]s.
///
/// The codex protocol is rich (50+ notification methods); the bridge SSE
/// surface is narrower and assumes opencode-style semantics. Where there
/// is no clean opencode analog, we fall back to the closest existing
/// event (e.g. errors become [BridgeSseSessionError]; thread status
/// changes become [BridgeSseSessionStatus] with a structured map).
///
/// Returning `null` drops a notification rather than emitting noise —
/// e.g. `account/rateLimits/updated` doesn't have a mobile UI today.
class CodexEventMapper {
  const CodexEventMapper();

  /// Maps a single notification. Returns null when the notification has
  /// no useful bridge representation today.
  BridgeSseEvent? map(CodexServerNotification notification) {
    final method = notification.method;
    final params = notification.params;

    switch (method) {
      case "thread/started":
        final thread = (params["thread"] as Map?)?.cast<String, dynamic>();
        if (thread == null) return null;
        return BridgeSseSessionCreated(info: thread);

      case "thread/status/changed":
        final threadId = params["threadId"] as String?;
        final status = params["status"];
        if (threadId == null) return null;
        return BridgeSseSessionStatus(
          sessionID: threadId,
          status: {"status": status},
        );

      case "thread/name/updated":
      case "thread/tokenUsage/updated":
      case "thread/archived":
      case "thread/unarchived":
        return BridgeSseSessionUpdated(info: params);

      case "thread/closed":
        final threadId = params["threadId"] as String?;
        if (threadId == null) return null;
        return BridgeSseSessionDeleted(info: params);

      case "turn/started":
        final threadId = params["threadId"] as String?;
        if (threadId == null) return null;
        return BridgeSseSessionStatus(
          sessionID: threadId,
          status: const {"state": "running"},
        );

      case "turn/completed":
        final threadId = params["threadId"] as String?;
        if (threadId == null) return null;
        return BridgeSseSessionIdle(sessionID: threadId);

      case "item/started":
      case "item/completed":
        return BridgeSseMessageUpdated(info: params);

      case "item/agentMessage/delta":
        final threadId = params["threadId"] as String?;
        final itemId = params["itemId"] as String?;
        final delta = params["delta"] as String?;
        if (threadId == null || itemId == null || delta == null) return null;
        return BridgeSseMessagePartDelta(
          sessionID: threadId,
          messageID: itemId,
          partID: "$itemId-text",
          field: "text",
          delta: delta,
        );

      case "item/reasoning/textDelta":
      case "item/reasoning/summaryTextDelta":
        final threadId = params["threadId"] as String?;
        final itemId = params["itemId"] as String?;
        final delta = params["delta"] as String?;
        if (threadId == null || itemId == null || delta == null) return null;
        return BridgeSseMessagePartDelta(
          sessionID: threadId,
          messageID: itemId,
          partID: "$itemId-reasoning",
          field: "text",
          delta: delta,
        );

      case "item/commandExecution/outputDelta":
      case "command/exec/outputDelta":
        // Surface the underlying message activity; opencode parity makes
        // mobile show "command running" through the same message update
        // channel.
        return BridgeSseMessageUpdated(info: params);

      case "item/autoApprovalReview/started":
        // Codex's approval flow surfaces as a permission ask. Phase 5
        // will fill in id/tool/description fields against the real
        // protocol — for now we record the raw payload as a session
        // update so the mobile UI knows something is up.
        return BridgeSseSessionUpdated(info: params);

      case "error":
        final threadId = params["threadId"] as String?;
        return BridgeSseSessionError(sessionID: threadId);

      case "turn/diff/updated":
        final threadId = params["threadId"] as String?;
        if (threadId == null) return null;
        return BridgeSseSessionDiff(sessionID: threadId);

      case "skills/changed":
      case "mcpServer/startupStatus/updated":
        return const BridgeSseProjectUpdated();

      // Notifications without a current mobile-facing analog — drop
      // them rather than emit noise. These can graduate to real events
      // as the mobile UI grows new affordances.
      case "account/updated":
      case "account/rateLimits/updated":
      case "app/list/updated":
      case "fs/changed":
      case "configWarning":
      case "deprecationNotice":
      case "model/rerouted":
      case "thread/compacted":
        return null;
    }

    // Realtime / fuzzy-search families and any future additions: drop.
    return null;
  }
}
