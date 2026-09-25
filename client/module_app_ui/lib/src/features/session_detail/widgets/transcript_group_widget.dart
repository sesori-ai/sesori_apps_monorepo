import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";
import "../session_detail_presentation_scope.dart";
import "reasoning_part_card.dart";
import "subtask_part_widget.dart";
import "tool_part_widget.dart";
import "transcript_live_row.dart";
import "transcript_motion.dart";
import "transcript_rolling_line.dart";

/// A run of tool, thinking and sub-agent steps: one summary row, with each
/// running step below it as a live row until it finishes and folds into the
/// summary, whose count rolls to take it in.
///
/// Tapping the summary opens the finished steps outside the transcript, so a
/// long group never pushes the conversation around: an anchored popover under
/// a pointer, a sheet under touch.
///
/// A lone finished step needs no summary: it keeps its own row, in step order,
/// and folds into the summary once a second step finishes.
class const TranscriptGroupWidget({
  super.key,
  required final String? projectId,
  required final TranscriptGroupBlock group,
}) extends StatelessWidget {
  /// The popover's size: wide enough for a command, short enough to stay a
  /// glance; past the height its steps scroll.
  static const double panelWidth = 560;
  static const double panelMaxHeight = 480;

  @override
  Widget build(BuildContext context) {
    final finishedSteps = group.finishedSteps;
    return TranscriptPresenceColumn(
      children: [
        if (finishedSteps.length == 1)
          for (final step in group.steps) _step(step: step)
        else ...[
          if (finishedSteps.isNotEmpty) _summary(context: context),
          for (final step in group.runningSteps) _step(step: step),
        ],
      ],
    );
  }

  Widget _summary({required BuildContext context}) {
    final prego = context.prego;
    Widget button({required VoidCallback onPressed}) => TextButton(
      key: ValueKey("transcriptGroup.toggle.${group.id}"),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: prego.colors.textSecondary,
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: AlignmentDirectional.centerStart,
        // The default stadium hover reads as a pill across the whole row.
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PregoRadius.xs)),
      ),
      child: _SummaryRow(summary: group.summary),
    );
    // Spaced as a step row is.
    return Padding(
      key: const ValueKey("transcriptGroup.summary"),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: switch (PregoInteractionScope.of(context)) {
        PregoInteractionMode.pointer => PregoPopover(
          popoverWidth: panelWidth,
          popoverMaxHeight: panelMaxHeight,
          contentScrolls: false,
          onClosed: null,
          triggerBuilder: (_, open) => button(onPressed: open),
          contentBuilder: (_, close) => _panel(from: context, close: close, padding: EdgeInsets.all(prego.spacing.lg)),
        ),
        PregoInteractionMode.touch => button(
          onPressed: () => showPregoModal<void>(
            context: context,
            title: _SummaryRow.label(loc: context.loc, summary: group.summary),
            builder: (sheetContext) => _panel(
              from: context,
              close: () => sheetContext.pop(),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      },
    );
  }

  /// The finished steps, as they were when the group opened. The panel is a
  /// route of its own, so it takes the session page's scope and cubit along,
  /// and its own selection area. Opening a sub-agent leaves the session, so
  /// the panel [close]s first rather than waiting under the next page.
  Widget _panel({required BuildContext from, required VoidCallback close, required EdgeInsetsGeometry padding}) {
    final scope = SessionDetailPresentationScope.read(from);
    return scope.around(
      openSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) {
        close();
        scope.openSession(projectId: projectId, sessionId: sessionId, sessionTitle: sessionTitle, readOnly: readOnly);
      },
      child: BlocProvider.value(
        value: from.read<SessionDetailCubit>(),
        child: PregoReadableSelectionArea(
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final step in group.finishedSteps) _step(step: step)],
            ),
          ),
        ),
      ),
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

class const _SummaryRow({required final TranscriptSummary summary}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final style = prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary);
    // Hugs its text, so the popover centres under the summary, not the row.
    // The chevron sits in a step row's icon slot, so the text lines up.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: TranscriptLiveSparkle.size,
          child: Icon(TablerRegular.chevron_right, size: PregoIconSize.sm, color: style.color),
        ),
        SizedBox(width: prego.spacing.md),
        // The counts ellipsize on a narrow screen; the failure count never does.
        Flexible(
          child: TranscriptRollingLine(
            segments: _counts(loc: loc, summary: summary),
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Built with no segment while nothing failed, so the first failure
        // wipes in rather than appearing.
        TranscriptRollingLine(
          segments: _failed(loc: loc, summary: summary),
          style: style.copyWith(color: prego.colors.textErrorPrimary),
          overflow: TextOverflow.clip,
        ),
      ],
    );
  }

  /// The whole summary as one line, such as a sheet's title.
  static String label({required AppLocalizations loc, required TranscriptSummary summary}) => [
    ..._counts(loc: loc, summary: summary),
    ..._failed(loc: loc, summary: summary),
  ].map((segment) => segment.text).join();

  static List<TranscriptLineSegment> _counts({required AppLocalizations loc, required TranscriptSummary summary}) => [
    for (final (index, count) in summary.counts.indexed)
      (key: count.kind, text: "${index > 0 ? " · " : ""}${_countLabel(loc: loc, count: count)}"),
  ];

  static List<TranscriptLineSegment> _failed({required AppLocalizations loc, required TranscriptSummary summary}) => [
    if (summary.failedCount > 0)
      (key: TranscriptStepStatus.failed, text: " · ${loc.transcriptSummaryFailed(summary.failedCount)}"),
  ];

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
