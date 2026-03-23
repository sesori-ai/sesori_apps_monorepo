import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "../../../core/routing/app_router.dart";
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
          _buildFooter(context),
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

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final sessionId = message.info.sessionID;
    final messageId = message.info.parentID ?? message.info.id;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _navigateToDiffs(context, sessionId, messageId),
            icon: const Icon(Icons.difference_outlined, size: 14),
            label: const Text(
              'View changes',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDiffs(BuildContext context, String sessionId, String messageId) {
    context.pushRoute(
      AppRoute.sessionDiffs,
      pathParams: {"sessionId": sessionId},
      queryParams: {"messageId": messageId},
    );
  }
}
