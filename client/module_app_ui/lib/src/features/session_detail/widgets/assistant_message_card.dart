import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "agent_part_widget.dart";
import "attachment_collection_widget.dart";
import "compaction_part_widget.dart";
import "retry_part_widget.dart";
import "text_part_widget.dart";
import "transcript_group_widget.dart";

/// An assistant message's row, rendering the blocks [TranscriptBuilder] made
/// for it. A row whose steps joined an earlier message's group is empty.
class const AssistantMessageCard({
  super.key,
  required final String? projectId,
  required final List<TranscriptBlock> blocks,
  required final Map<String, String> streamingText,
  required final EdgeInsetsGeometry contentPadding,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: contentPadding,
      child: PregoReadableSelectionArea(
        child: Column(
          crossAxisAlignment: .start,
          children: [
            for (final block in blocks)
              ...switch (block) {
                TranscriptPartsBlock(:final parts) => _buildParts(context: context, parts: parts),
                TranscriptGroupBlock() => [
                  TranscriptGroupWidget(key: ValueKey(block.id), projectId: projectId, group: block),
                ],
              },
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
    MessagePartAgent() ||
    MessagePartRetry() ||
    MessagePartCompaction() ||
    MessagePartFile() => true,
    MessagePartReasoning() ||
    MessagePartTool() ||
    MessagePartSubtask() ||
    MessagePartStepStart() ||
    MessagePartStepFinish() ||
    MessagePartSnapshot() ||
    MessagePartPatch() ||
    MessagePartCompaction() => false,
  };

  Widget _buildPart({required BuildContext context, required MessagePart part}) {
    final streaming = streamingText[part.id];

    return switch (part) {
      MessagePartText(:final text) => TextPartWidget(
        key: ValueKey(part.id),
        text: streaming ?? text,
        isStreaming: streaming != null,
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
      MessagePartCompaction(:final summary) => CompactionPartWidget(key: ValueKey(part.id), summary: summary),
      // Steps render in their group; the builder never puts them here.
      MessagePartReasoning() ||
      MessagePartTool() ||
      MessagePartSubtask() ||
      MessagePartStepStart() ||
      MessagePartStepFinish() ||
      MessagePartFile() ||
      MessagePartSnapshot() ||
      MessagePartPatch() => const SizedBox.shrink(),
    };
  }
}
