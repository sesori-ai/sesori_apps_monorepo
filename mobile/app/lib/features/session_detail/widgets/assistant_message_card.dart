import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "agent_part_widget.dart";
import "reasoning_part_widget.dart";
import "retry_part_widget.dart";
import "subtask_part_widget.dart";
import "text_part_widget.dart";
import "tool_part_widget.dart";

class AssistantMessageCard extends StatelessWidget {
  final String? projectId;
  final MessageWithParts message;
  final Map<String, String> streamingText;
  final List<Session> children;
  final Map<String, SessionStatus> childStatuses;

  const AssistantMessageCard({
    super.key,
    required this.projectId,
    required this.message,
    required this.streamingText,
    required this.children,
    required this.childStatuses,
  });

  @override
  Widget build(BuildContext context) {
    final visibleParts = message.parts.where(_isVisible).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          for (final part in visibleParts) _buildPart(context: context, part: part),
        ],
      ),
    );
  }

  bool _isVisible(MessagePart part) {
    return const [
      MessagePartType.text,
      MessagePartType.reasoning,
      MessagePartType.tool,
      MessagePartType.subtask,
      MessagePartType.stepStart,
      MessagePartType.stepFinish,
      MessagePartType.agent,
      MessagePartType.retry,
    ].contains(part.type);
  }

  Widget _buildPart({required BuildContext context, required MessagePart part}) {
    final streaming = streamingText[part.id];

    return switch (part.type) {
      MessagePartType.text => TextPartWidget(
        key: ValueKey(part.id),
        text: streaming ?? part.text ?? "",
        isStreaming: streaming != null,
      ),
      MessagePartType.reasoning => ReasoningPartWidget(
        key: ValueKey(part.id),
        text: streaming ?? part.text ?? "",
        isStreaming: streaming != null,
      ),
      MessagePartType.tool => ToolPartWidget(key: ValueKey(part.id), part: part),
      MessagePartType.subtask => SubtaskPartWidget(
        key: ValueKey(part.id),
        projectId: projectId,
        part: part,
        children: children,
        childStatuses: childStatuses,
      ),
      MessagePartType.agent => AgentPartWidget(
        key: ValueKey(part.id),
        agentName: part.agentName,
      ),
      MessagePartType.retry => RetryPartWidget(
        key: ValueKey(part.id),
        attempt: part.attempt,
        retryError: part.retryError,
      ),
      MessagePartType.stepStart => const SizedBox.shrink(),
      MessagePartType.stepFinish => const SizedBox.shrink(),
      MessagePartType.file => const SizedBox.shrink(),
      MessagePartType.snapshot => const SizedBox.shrink(),
      MessagePartType.patch => const SizedBox.shrink(),
      MessagePartType.compaction => const SizedBox.shrink(),
    };
  }
}
