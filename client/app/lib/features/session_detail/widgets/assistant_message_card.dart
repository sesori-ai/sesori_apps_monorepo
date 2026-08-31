import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

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
  required final EdgeInsetsGeometry contentPadding,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: contentPadding,
      child: PregoReadableSelectionArea(
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
      if (part is! MessagePartFile) {
        if (_isVisible(part)) widgets.add(_buildPart(context: context, part: part));
        index++;
        continue;
      }

      final run = <MessagePartFile>[];
      while (index < parts.length) {
        final candidate = parts[index];
        if (candidate is! MessagePartFile) break;
        run.add(candidate);
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

  bool _isVisible(MessagePart part) => switch (part) {
    MessagePartText() ||
    MessagePartReasoning() ||
    MessagePartTool() ||
    MessagePartSubtask() ||
    MessagePartStepStart() ||
    MessagePartStepFinish() ||
    MessagePartAgent() ||
    MessagePartRetry() ||
    MessagePartFile() => true,
    MessagePartSnapshot() || MessagePartPatch() || MessagePartCompaction() => false,
  };

  Widget _buildPart({required BuildContext context, required MessagePart part}) {
    final streaming = streamingText[part.id];

    return switch (part) {
      MessagePartText(:final text) => TextPartWidget(
        key: ValueKey(part.id),
        text: streaming ?? text,
        isStreaming: streaming != null,
      ),
      MessagePartReasoning(:final text) => ReasoningPartCard(
        key: ValueKey(part.id),
        text: streaming ?? text,
        isStreaming: streaming != null,
        partId: part.id,
        messageId: message.info.id,
      ),
      MessagePartTool() => ToolPartWidget(key: ValueKey(part.id), part: part),
      MessagePartSubtask() => SubtaskPartWidget(
        key: ValueKey(part.id),
        projectId: projectId,
        bridgeId: bridgeId,
        part: part,
        children: children,
        childStatuses: childStatuses,
      ),
      MessagePartAgent(:final agentName) => AgentPartWidget(
        key: ValueKey(part.id),
        agentName: agentName,
      ),
      MessagePartRetry(:final attempt, :final retryError) => RetryPartWidget(
        key: ValueKey(part.id),
        attempt: attempt,
        retryError: retryError,
      ),
      MessagePartStepStart() ||
      MessagePartStepFinish() ||
      MessagePartFile() ||
      MessagePartSnapshot() ||
      MessagePartPatch() ||
      MessagePartCompaction() => const SizedBox.shrink(),
    };
  }
}
