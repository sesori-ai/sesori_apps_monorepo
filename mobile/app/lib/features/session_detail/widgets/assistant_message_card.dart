import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "reasoning_part_widget.dart";
import "subtask_part_widget.dart";
import "text_part_widget.dart";
import "tool_part_widget.dart";

class AssistantMessageCard extends StatelessWidget {
  final MessageWithParts message;
  final Map<String, String> streamingText;
  final List<Session> children;
  final Map<String, SessionStatus> childStatuses;

  const AssistantMessageCard({
    super.key,
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
          for (final part in visibleParts) _buildPart(context, part),
        ],
      ),
    );
  }

  bool _isVisible(MessagePart part) {
    return const [
      "text",
      "reasoning",
      "tool",
      "subtask",
      "step-start",
      "step-finish",
    ].contains(part.type);
  }

  Widget _buildPart(BuildContext context, MessagePart part) {
    final streaming = streamingText[part.id];

    return switch (part.type) {
      "text" => TextPartWidget(
        key: ValueKey(part.id),
        text: streaming ?? part.text ?? "",
        isStreaming: streaming != null,
      ),
      "reasoning" => ReasoningPartWidget(
        key: ValueKey(part.id),
        text: streaming ?? part.text ?? "",
        isStreaming: streaming != null,
      ),
      "tool" => ToolPartWidget(key: ValueKey(part.id), part: part),
      "subtask" => SubtaskPartWidget(
        key: ValueKey(part.id),
        part: part,
        children: children,
        childStatuses: childStatuses,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
