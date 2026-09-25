import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../session_detail_presentation_scope.dart";
import "transcript_live_row.dart";

/// A sub-agent's row: the agent, then its task. A finished one says nothing
/// more; a failed one keeps one signal, its icon.
class const SubtaskPartWidget({
  super.key,
  required final String? projectId,
  required final MessagePartSubtask part,

  /// The child session running it, resolved by [TranscriptBuilder].
  required final Session? childSession,
  required final TranscriptStepStatus status,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final description = part.description.isNotEmpty
        ? part.description
        : part.prompt.isNotEmpty
        ? part.prompt
        : loc.sessionDetailSubtaskUnnamed;
    final childSession = this.childSession;
    final targetSessionId = part.childSessionID ?? childSession?.id;
    final targetProjectId = projectId ?? childSession?.projectID;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          mouseCursor: WidgetStateMouseCursor.clickable,
          borderRadius: BorderRadius.circular(PregoRadius.xs),
          onTap: targetSessionId != null && targetProjectId != null
              ? () => SessionDetailPresentationScope.read(context).openSession(
                  projectId: targetProjectId,
                  sessionId: targetSessionId,
                  sessionTitle: childSession?.title ?? description,
                  readOnly: true,
                )
              : null,
          child: Row(
            children: [
              Expanded(
                child: TranscriptStepRow(
                  leading: switch (status) {
                    TranscriptStepStatus.running => const TranscriptLiveSparkle(),
                    TranscriptStepStatus.finished => Icon(
                      TablerRegular.robot,
                      size: PregoIconSize.sm,
                      color: prego.colors.textTertiary,
                    ),
                    TranscriptStepStatus.failed => Icon(
                      TablerSolid.alert_circle,
                      size: PregoIconSize.sm,
                      color: prego.colors.fgErrorPrimary,
                    ),
                  },
                  label: part.agent.isNotEmpty ? part.agent : loc.sessionDetailAgentFallback,
                  detail: TextSpan(text: description),
                  live: status == TranscriptStepStatus.running,
                  color: null,
                  below: null,
                ),
              ),
              if (targetSessionId != null && targetProjectId != null)
                Icon(
                  TablerRegular.chevron_right,
                  size: PregoIconSize.md,
                  color: prego.colors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
