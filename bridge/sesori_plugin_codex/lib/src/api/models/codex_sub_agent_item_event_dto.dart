import "codex_correlatable_item_event_dto.dart";
import "codex_sub_agent_item_dto.dart";

/// A `subAgentActivity` item observed on a parent thread: a lifecycle fact
/// about one child thread. The item id is the parent's spawn tool-call id,
/// which ties it to the tool call persisted in the parent rollout.
final class const CodexSubAgentActivity({
  required final CodexCorrelatableItemLifecycle lifecycle,
  required final String threadId,
  required final String? turnId,
  required final String itemId,
  required final CodexSubAgentActivityKind kind,
  required final String agentThreadId,
  required final String? agentPath,
  required final String? model,
  required final String? reasoningEffort,
});
