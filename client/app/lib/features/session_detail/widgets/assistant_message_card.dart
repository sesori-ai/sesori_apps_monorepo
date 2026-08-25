import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";

import "agent_part_widget.dart";
import "attachment_collection_widget.dart";
import "reasoning_part_card.dart";
import "retry_part_widget.dart";
import "subtask_part_widget.dart";
import "text_part_widget.dart";
import "tool_part_widget.dart";

class const AssistantMessageCard({
  super.key,
  required final String? projectId,
  required final String? bridgeId,
  required final MessageWithParts message,
  required final Map<String, String> streamingText,
  required final List<Session> children,
  required final Map<String, SessionStatus> childStatuses,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: .start,
          children: [
            ..._buildParts(context: context, parts: message.parts),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildParts({required BuildContext context, required List<MessagePart> parts}) {
    final widgets = <Widget>[];
    var index = 0;
    while (index < parts.length) {
      final part = parts[index];
      if (part.type != MessagePartType.file) {
        if (_isVisible(part)) widgets.add(_buildPart(context: context, part: part));
        index++;
        continue;
      }

      final run = <MessagePart>[];
      while (index < parts.length && parts[index].type == MessagePartType.file) {
        run.add(parts[index]);
        index++;
      }
      final attachments = run.map((part) => part.attachment).whereType<MessageAttachment>().toList();
      if (attachments.isNotEmpty) {
        widgets.add(
          AttachmentCollectionWidget(
            key: ValueKey(run.first.id),
            sessionId: run.first.sessionID,
            attachments: attachments,
          ),
        );
      }
    }
    return widgets;
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
      MessagePartType.file,
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
      MessagePartType.reasoning => ReasoningPartCard(
        key: ValueKey(part.id),
        text: streaming ?? part.text ?? "",
        isStreaming: streaming != null,
        partId: part.id,
        messageId: message.info.id,
      ),
      MessagePartType.tool => ToolPartWidget(key: ValueKey(part.id), part: part),
      MessagePartType.subtask => SubtaskPartWidget(
        key: ValueKey(part.id),
        projectId: projectId,
        bridgeId: bridgeId,
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
