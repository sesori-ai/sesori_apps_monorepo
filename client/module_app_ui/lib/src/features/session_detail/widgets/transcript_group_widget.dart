import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
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
    final finishedCount = group.finishedSteps.length;
    return TranscriptPresenceColumn(
      children: [
        if (finishedCount > 0) _summary(context: context, finishedCount: finishedCount),
        for (final step in group.runningSteps) _step(step: step),
      ],
    );
  }

  Widget _summary({required BuildContext context, required int finishedCount}) {
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
      child: _SummaryRow(finishedCount: finishedCount),
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
            title: context.loc.transcriptSummarySteps(finishedCount),
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

/// The keys of a summary line's segments.
enum _SummarySegment() {
  steps,
}

class const _SummaryRow({required final int finishedCount}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
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
        // Rolls its count as a live row folds in; ellipsizes on a narrow screen.
        Flexible(
          child: TranscriptRollingLine(
            segments: [(key: _SummarySegment.steps, text: context.loc.transcriptSummarySteps(finishedCount))],
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
