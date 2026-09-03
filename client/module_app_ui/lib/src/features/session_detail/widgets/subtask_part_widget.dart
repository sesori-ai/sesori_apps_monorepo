import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";
import "../session_detail_presentation_scope.dart";

class const SubtaskPartWidget({
  super.key,
  required final String? projectId,
  required final MessagePartSubtask part,
  required final List<Session> children,
  required final Map<String, SessionStatus> childStatuses,
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

    final childSession = _resolveChildSession();
    final targetSessionId = part.childSessionID ?? childSession?.id;
    final targetProjectId = projectId ?? childSession?.projectID;
    // A backend that reports the subtask's own lifecycle is authoritative for
    // it. Otherwise the child session's status is the only signal available.
    final status = part.taskState?.status;
    final childStatus = childSession == null ? null : childStatuses[childSession.id] ?? const SessionStatus.idle();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: prego.colors.bgSecondary,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
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
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: prego.colors.borderSecondary),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                status == null
                    ? _sessionStatusIcon(status: childStatus, prego: prego)
                    : _subtaskStatusIcon(status: status, prego: prego),
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
                if (status != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: Text(
                      _statusLabel(loc: loc, status: status),
                      style: prego.textTheme.textXs.medium.copyWith(
                        color: prego.colors.textSecondary,
                      ),
                    ),
                  ),
                if (targetSessionId != null && targetProjectId != null)
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: prego.colors.textSecondary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _subtaskStatusIcon({required ToolStatus status, required PregoDesignSystem prego}) => switch (status) {
    ToolStatus.pending || ToolStatus.running => const SizedBox(
      width: 16,
      height: 16,
      child: PregoActivityIndicator(color: null),
    ),
    ToolStatus.completed => Icon(
      Icons.check_circle,
      size: 16,
      color: prego.colors.bgBrandSolid,
    ),
    ToolStatus.error => Icon(Icons.error, size: 16, color: prego.colors.fgErrorPrimary),
    ToolStatus.cancelled => Icon(Icons.cancel, size: 16, color: prego.colors.textSecondary),
    ToolStatus.unknown => Icon(
      Icons.play_circle_outline,
      size: 16,
      color: prego.colors.borderPrimary,
    ),
  };

  String _statusLabel({required AppLocalizations loc, required ToolStatus status}) => switch (status) {
    ToolStatus.pending => loc.sessionDetailToolPending,
    ToolStatus.running => loc.sessionDetailToolRunning,
    ToolStatus.completed => loc.sessionDetailToolCompleted,
    ToolStatus.error => loc.sessionDetailToolError,
    ToolStatus.cancelled => loc.sessionDetailToolCancelled,
    ToolStatus.unknown => loc.sessionDetailToolUnknown,
  };

  Widget _sessionStatusIcon({required SessionStatus? status, required PregoDesignSystem prego}) => switch (status) {
    SessionStatusBusy() || SessionStatusRetry() => const SizedBox(
      width: 16,
      height: 16,
      child: PregoActivityIndicator(color: null),
    ),
    SessionStatusIdle() => Icon(
      Icons.check_circle,
      size: 16,
      color: prego.colors.bgBrandSolid,
    ),
    null => Icon(
      Icons.play_circle_outline,
      size: 16,
      color: prego.colors.borderPrimary,
    ),
  };

  /// The child session this subtask runs in.
  ///
  /// A backend that names it on the part is authoritative, so only the id is
  /// matched then — the lookup merely enriches the tile and its absence is
  /// normal while the child is still being published. Backends that name no
  /// child fall back to matching the description against child titles.
  Session? _resolveChildSession() {
    if (part.childSessionID case final childSessionID?) {
      for (final child in children) {
        if (child.id == childSessionID) return child;
      }
      return null;
    }
    if (children.isEmpty) return null;
    // If there's only one child, it's likely the one.
    if (children.length == 1) return children.first;

    final desc = part.description.isNotEmpty
        ? part.description
        : part.prompt.isNotEmpty
        ? part.prompt
        : null;
    if (desc == null) return null;

    // 1. Exact match.
    for (final child in children) {
      if (child.title == desc) return child;
    }

    // 2. Case-insensitive match.
    final descLower = desc.toLowerCase();
    for (final child in children) {
      if (child.title?.toLowerCase() == descLower) return child;
    }

    // 3. Contains match (either direction).
    for (final child in children) {
      final titleLower = child.title?.toLowerCase();
      if (titleLower != null && (titleLower.contains(descLower) || descLower.contains(titleLower))) {
        return child;
      }
    }

    return null;
  }
}
