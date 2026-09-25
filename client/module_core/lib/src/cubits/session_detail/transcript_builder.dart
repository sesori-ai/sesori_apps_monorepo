import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Where a transcript step is in its lifecycle. A cancelled or unknown tool
/// counts as finished: only a failure carries a signal.
enum TranscriptStepStatus() {
  running,
  finished,
  failed,
}

/// What a summary counts, in the order its kinds first appear. Tool calls count
/// by the kind their plugin reported; [tool] holds the rest as plain steps.
enum TranscriptStepKind() {
  thinking,
  read,
  edit,
  command,
  search,
  tool,
  subAgent,
}

/// One tool, thinking or sub-agent part inside a [TranscriptGroupBlock].
@immutable
sealed class const TranscriptStep({required final TranscriptStepStatus status}) {
  String get id;
  TranscriptStepKind get kind;
}

final class const TranscriptThinkingStep({
  required final MessagePartReasoning part,

  /// The streamed text while it streams, else the part's own text.
  required final String text,
  required super.status,
}) extends TranscriptStep {
  @override
  String get id => part.id;

  @override
  TranscriptStepKind get kind => TranscriptStepKind.thinking;
}

final class const TranscriptToolStep({
  required final MessagePartTool part,
  required super.status,
}) extends TranscriptStep {
  @override
  String get id => part.id;

  @override
  TranscriptStepKind get kind => switch (part.kind) {
    ToolKind.read => TranscriptStepKind.read,
    ToolKind.edit => TranscriptStepKind.edit,
    ToolKind.command => TranscriptStepKind.command,
    ToolKind.search => TranscriptStepKind.search,
    ToolKind.other || ToolKind.unknown => TranscriptStepKind.tool,
  };
}

final class const TranscriptSubAgentStep({
  required final MessagePartSubtask part,

  /// The child session running the sub-agent, or null while none is known.
  required final Session? childSession,
  required super.status,
}) extends TranscriptStep {
  @override
  String get id => part.id;

  @override
  TranscriptStepKind get kind => TranscriptStepKind.subAgent;
}

/// How many finished steps of one kind a group holds.
typedef TranscriptKindCount = ({TranscriptStepKind kind, int count});

/// A group's collapsed line: finished steps counted by kind in order of first
/// appearance, plus failures. Running steps are not counted; they show as
/// live rows until they finish.
final class const TranscriptSummary({
  required final List<TranscriptKindCount> counts,
  required final int failedCount,
}) {
  bool get isEmpty => counts.isEmpty;
}

/// One piece of an assistant message's row.
@immutable
sealed class const TranscriptBlock();

/// Parts that render on their own, in order: text, files, agent switches and
/// retries, plus hidden parts that keep attachment runs apart.
final class const TranscriptPartsBlock({required final List<MessagePart> parts}) extends TranscriptBlock;

/// Consecutive tool, thinking, step and sub-agent parts. A group ends at every
/// piece of text, so steps, a sentence and more steps keep their order, and it
/// may span several assistant messages.
final class const TranscriptGroupBlock({
  /// The first grouped part's id, stable while the group grows.
  required final String id,
  required final List<TranscriptStep> steps,
  required final TranscriptSummary summary,
}) extends TranscriptBlock {
  List<TranscriptStep> get finishedSteps => [
    for (final step in steps)
      if (step.status != TranscriptStepStatus.running) step,
  ];

  List<TranscriptStep> get runningSteps => [
    for (final step in steps)
      if (step.status == TranscriptStepStatus.running) step,
  ];
}

/// The loaded messages arranged for rendering.
final class const Transcript({
  /// Blocks for each assistant message row. A group that spans messages sits
  /// in the row of the message it started in, so later rows may be empty.
  required final Map<String, List<TranscriptBlock>> blocksByMessageId,
}) {
  List<TranscriptBlock> blocksFor({required String messageId}) => blocksByMessageId[messageId] ?? const [];
}

/// Groups and counts transcript steps. Pure and stateless: it reads messages
/// and returns blocks, so the message list can run it over whatever it renders,
/// including the snapshot it holds while the reader is scrolled away.
class const TranscriptBuilder() {
  Transcript build({
    required List<MessageWithParts> messages,
    required Map<String, String> streamingText,
    required List<Session> children,
    required Map<String, SessionStatus> childStatuses,
  }) {
    final pendingByMessageId = <String, List<_PendingBlock>>{};
    _OpenGroup? group;

    for (final message in messages) {
      final info = message.info;
      if (info is! MessageAssistant) {
        group = null;
        continue;
      }
      // Automation messages render in their own frame, so their steps never
      // join a group from outside it.
      final isAgent = info.sender == MessageSender.agent;
      if (!isAgent) group = null;
      final blocks = pendingByMessageId[info.id] = [];

      for (final part in message.parts) {
        final step = _stepFor(
          part: part,
          streamingText: streamingText,
          children: children,
          childStatuses: childStatuses,
        );
        if (step != null) {
          var open = group;
          if (open == null) {
            open = group = _OpenGroup(id: part.id);
            blocks.add(open);
          }
          open.steps.add(step);
          continue;
        }
        if (_isHidden(part: part, streamingText: streamingText)) {
          // Hidden parts never end a group, but they still separate the
          // attachment runs of the parts block they fall in.
          if (blocks.lastOrNull case _PendingParts(:final parts)) parts.add(part);
          continue;
        }
        group = null;
        if (blocks.lastOrNull case _PendingParts(:final parts)) {
          parts.add(part);
        } else {
          blocks.add(_PendingParts(parts: [part]));
        }
      }

      if (!isAgent) group = null;
    }

    return Transcript(
      blocksByMessageId: {
        for (final MapEntry(:key, :value) in pendingByMessageId.entries)
          key: [
            for (final block in value)
              switch (block) {
                _PendingParts(:final parts) => TranscriptPartsBlock(parts: List.unmodifiable(parts)),
                _OpenGroup() => block.close(),
              },
          ],
      },
    );
  }

  /// The child session a sub-agent runs in.
  ///
  /// A backend that names it on the part is authoritative, so only the id is
  /// matched then; its absence is normal while the child is still being
  /// published. Backends that name no child fall back to matching the
  /// description against child titles.
  Session? childSessionFor({required MessagePartSubtask part, required List<Session> children}) {
    if (part.childSessionID case final childSessionID?) {
      return children.where((child) => child.id == childSessionID).firstOrNull;
    }
    if (children.isEmpty) return null;
    // If there's only one child, it's likely the one.
    if (children.length == 1) return children.first;

    final description = part.description.isNotEmpty
        ? part.description
        : part.prompt.isNotEmpty
        ? part.prompt
        : null;
    if (description == null) return null;

    final exact = children.where((child) => child.title == description).firstOrNull;
    if (exact != null) return exact;

    final lower = description.toLowerCase();
    final caseInsensitive = children.where((child) => child.title?.toLowerCase() == lower).firstOrNull;
    if (caseInsensitive != null) return caseInsensitive;

    return children.where((child) {
      final title = child.title?.toLowerCase();
      return title != null && (title.contains(lower) || lower.contains(title));
    }).firstOrNull;
  }

  TranscriptStep? _stepFor({
    required MessagePart part,
    required Map<String, String> streamingText,
    required List<Session> children,
    required Map<String, SessionStatus> childStatuses,
  }) {
    switch (part) {
      case MessagePartTool(:final state):
        return TranscriptToolStep(
          part: part,
          status: _toolStatus(status: state.status),
        );
      case MessagePartReasoning(:final text):
        final streaming = streamingText[part.id];
        if (streaming != null) {
          return TranscriptThinkingStep(part: part, text: streaming, status: TranscriptStepStatus.running);
        }
        if (text.isEmpty) return null;
        return TranscriptThinkingStep(part: part, text: text, status: TranscriptStepStatus.finished);
      case MessagePartSubtask(:final taskState):
        final childSession = childSessionFor(part: part, children: children);
        final TranscriptStepStatus status;
        if (taskState != null) {
          // A backend that reports the sub-agent's own lifecycle is authoritative.
          status = _toolStatus(status: taskState.status);
        } else if (childSession != null) {
          status = switch (childStatuses[childSession.id]) {
            SessionStatusBusy() || SessionStatusRetry() => TranscriptStepStatus.running,
            SessionStatusIdle() || null => TranscriptStepStatus.finished,
          };
        } else {
          status = TranscriptStepStatus.finished;
        }
        return TranscriptSubAgentStep(part: part, childSession: childSession, status: status);
      case MessagePartText() ||
          MessagePartFile() ||
          MessagePartAgent() ||
          MessagePartRetry() ||
          MessagePartStepStart() ||
          MessagePartStepFinish() ||
          MessagePartSnapshot() ||
          MessagePartPatch() ||
          MessagePartCompaction():
        return null;
    }
  }

  /// Whether [part] shows nothing, so it neither ends a group nor starts a
  /// parts block. Empty reasoning never reaches here; it is dropped as a step.
  bool _isHidden({required MessagePart part, required Map<String, String> streamingText}) => switch (part) {
    MessagePartText(:final text) => text.isEmpty && !streamingText.containsKey(part.id),
    MessagePartReasoning() ||
    MessagePartStepStart() ||
    MessagePartStepFinish() ||
    MessagePartSnapshot() ||
    MessagePartPatch() ||
    MessagePartCompaction() => true,
    MessagePartFile() || MessagePartAgent() || MessagePartRetry() || MessagePartTool() || MessagePartSubtask() => false,
  };

  static TranscriptStepStatus _toolStatus({required ToolStatus status}) => switch (status) {
    ToolStatus.pending || ToolStatus.running => TranscriptStepStatus.running,
    ToolStatus.error => TranscriptStepStatus.failed,
    ToolStatus.completed || ToolStatus.cancelled || ToolStatus.unknown => TranscriptStepStatus.finished,
  };
}

/// A block still being built.
sealed class const _PendingBlock();

/// A parts block still collecting parts; frozen into [TranscriptPartsBlock].
final class const _PendingParts({required final List<MessagePart> parts}) extends _PendingBlock;

/// A group still collecting steps; frozen into [TranscriptGroupBlock].
final class _OpenGroup({required final String id}) extends _PendingBlock {
  final List<TranscriptStep> steps = [];

  TranscriptGroupBlock close() {
    final counts = <TranscriptStepKind, int>{};
    var failedCount = 0;
    for (final step in steps) {
      if (step.status == TranscriptStepStatus.running) continue;
      counts[step.kind] = (counts[step.kind] ?? 0) + 1;
      if (step.status == TranscriptStepStatus.failed) failedCount++;
    }
    return TranscriptGroupBlock(
      id: id,
      steps: List.unmodifiable(steps),
      summary: TranscriptSummary(
        counts: [for (final MapEntry(:key, :value) in counts.entries) (kind: key, count: value)],
        failedCount: failedCount,
      ),
    );
  }
}
