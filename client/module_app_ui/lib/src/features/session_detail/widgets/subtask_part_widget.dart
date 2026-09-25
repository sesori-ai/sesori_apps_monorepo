import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../session_detail_presentation_scope.dart";

/// A sub-agent's row. A finished one says nothing; a failed one keeps one
/// signal, its icon.
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
    final agent = part.agent;
    final childSession = this.childSession;
    final targetSessionId = part.childSessionID ?? childSession?.id;
    final targetProjectId = projectId ?? childSession?.projectID;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: prego.colors.bgSecondary,
        borderRadius: BorderRadius.circular(PregoRadius.md),
        child: InkWell(
          mouseCursor: WidgetStateMouseCursor.clickable,
          borderRadius: BorderRadius.circular(PregoRadius.md),
          onTap: targetSessionId != null && targetProjectId != null
              ? () => SessionDetailPresentationScope.read(context).openSession(
                  projectId: targetProjectId,
                  sessionId: targetSessionId,
                  sessionTitle: childSession?.title ?? description,
                  readOnly: true,
                )
              : null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PregoRadius.md),
              border: Border.all(color: prego.colors.borderSecondary),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                switch (status) {
                  TranscriptStepStatus.running => const SizedBox(
                    width: 16,
                    height: 16,
                    child: PregoActivityIndicator(color: null),
                  ),
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
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        description,
                        style: prego.textTheme.textSm.regular.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: .ellipsis,
                      ),
                      if (agent.isNotEmpty)
                        Text(
                          agent,
                          style: prego.textTheme.textXs.regular.copyWith(
                            color: prego.colors.textSecondary,
                          ),
                        ),
                    ],
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
      ),
    );
  }
}
