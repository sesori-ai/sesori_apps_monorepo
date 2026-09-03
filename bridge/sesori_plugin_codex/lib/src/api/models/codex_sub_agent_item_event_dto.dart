import "codex_correlatable_item_event_dto.dart";
import "codex_sub_agent_item_dto.dart";

/// A multi-agent item observed on a parent thread, typed at the boundary.
sealed class const CodexSubAgentItemEventDto({
    required final CodexCorrelatableItemLifecycle lifecycle,
    required final String threadId,
    required final String? turnId,
    required final String itemId,
  });

/// A `collabAgentToolCall` item: the parent invoking a multi-agent tool such
/// as `spawnAgent` or `wait`.
///
/// [receiverThreadIds] merges the 0.148.0 list with the upstream singular
/// `receiverThreadId`/`newThreadId` fields, so a spawn's child id is always the
/// first entry regardless of the emitting version.
final class const CodexCollabItem({
    required super.lifecycle,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required final CodexCollabTool tool,
    required final CodexCollabItemStatus status,
    required final String? senderThreadId,
    required final List<String> receiverThreadIds,
    required final String? prompt,
    required final Map<String, CodexCollabAgentStatus> agentsStates,
  }) extends CodexSubAgentItemEventDto;

/// A `subAgentActivity` item: a lifecycle fact about one child thread. The item
/// id is the parent's spawn tool-call id, which ties it to the tool call
/// persisted in the parent rollout.
final class const CodexSubAgentActivity({
    required super.lifecycle,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required final CodexSubAgentActivityKind kind,
    required final String agentThreadId,
    required final String? agentPath,
  }) extends CodexSubAgentItemEventDto;
