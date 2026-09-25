import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";
import "reasoning_part_card.dart";
import "subtask_part_widget.dart";
import "tool_part_widget.dart";
import "transcript_disclosure.dart";

/// A run of tool, thinking and sub-agent steps: one summary row that eases its
/// finished steps open, with each running step below it as a live row until it
/// finishes and folds into the summary.
class const TranscriptGroupWidget({
  super.key,
  required final String? projectId,
  required final TranscriptGroupBlock group,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final finished = group.finishedSteps;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (finished.isNotEmpty)
          TranscriptDisclosure(
            key: const ValueKey("transcriptGroup.summary"),
            toggleKey: ValueKey("transcriptGroup.toggle.${group.id}"),
            headerBuilder: ({required expanded}) => _SummaryRow(summary: group.summary, expanded: expanded),
            panel: Padding(
              padding: EdgeInsetsDirectional.only(start: context.prego.spacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final step in finished) _step(step: step)],
              ),
            ),
          ),
        for (final step in group.runningSteps) _step(step: step),
      ],
    );
  }

  Widget _step({required TranscriptStep step}) => switch (step) {
    TranscriptToolStep(:final part) => ToolPartWidget(key: ValueKey(step.id), part: part),
    TranscriptThinkingStep(:final part, :final text, :final status) => ReasoningPartCard(
      key: ValueKey(step.id),
      text: text,
      isStreaming: status == TranscriptStepStatus.running,
      partId: part.id,
      messageId: part.messageID,
    ),
    TranscriptSubAgentStep(:final part, :final childSession, :final status) => SubtaskPartWidget(
      key: ValueKey(step.id),
      projectId: projectId,
      part: part,
      childSession: childSession,
      status: status,
    ),
  };
}

class const _SummaryRow({required final TranscriptSummary summary, required final bool expanded})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final style = prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary);
    final failedCount = summary.failedCount;
    return Row(
      children: [
        Icon(
          expanded ? TablerRegular.chevron_down : TablerRegular.chevron_right,
          size: PregoIconSize.sm,
          color: style.color,
        ),
        SizedBox(width: prego.spacing.md),
        // The counts ellipsize on a narrow screen; the failure count never does.
        Flexible(
          child: Text(
            [for (final count in summary.counts) _countLabel(loc: loc, count: count)].join(" · "),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (failedCount > 0)
          Text(
            " · ${loc.transcriptSummaryFailed(failedCount)}",
            style: style.copyWith(color: prego.colors.textErrorPrimary),
            maxLines: 1,
          ),
      ],
    );
  }

  static String _countLabel({required AppLocalizations loc, required TranscriptKindCount count}) =>
      switch (count.kind) {
        TranscriptStepKind.thinking => loc.transcriptSummaryThought,
        TranscriptStepKind.read => loc.transcriptSummaryRead(count.count),
        TranscriptStepKind.edit => loc.transcriptSummaryEdited(count.count),
        TranscriptStepKind.command => loc.transcriptSummaryRan(count.count),
        TranscriptStepKind.search => loc.transcriptSummarySearches(count.count),
        TranscriptStepKind.tool => loc.transcriptSummarySteps(count.count),
        TranscriptStepKind.subAgent => loc.transcriptSummarySubAgents(count.count),
      };
}
