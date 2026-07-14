import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/routing/app_router.dart";
import "../../../core/routing/current_project_name.dart";
import "../../../core/widgets/throttled_activity_indicator.dart";

class SubtaskPartWidget extends StatelessWidget {
  final String? projectId;
  final MessagePart part;
  final List<Session> children;
  final Map<String, SessionStatus> childStatuses;

  const SubtaskPartWidget({
    super.key,
    required this.projectId,
    required this.part,
    required this.children,
    required this.childStatuses,
  });

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final description = part.description ?? part.prompt ?? loc.sessionDetailSubtaskUnnamed;
    final agent = part.agent;

    // Find the matching child session for this subtask.
    // Subtask parts don't have a direct child session ID, so we match by
    // description/prompt against the child session title, or show all if no match.
    final childSession = _findChildSession();
    final status = childSession != null ? childStatuses[childSession.id] ?? const SessionStatus.idle() : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: prego.colors.bgSecondary,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: childSession != null
              ? () => context.pushRoute(
                  AppRoute.sessionDetail(
                    projectId: projectId ?? childSession.projectID,
                    projectName: currentProjectName(context),
                    sessionId: childSession.id,
                    readOnly: true,
                    sessionTitle: childSession.title,
                  ),
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
                _statusIcon(status: status, prego: prego),
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
                      if (agent != null)
                        Text(
                          agent,
                          style: prego.textTheme.textXs.regular.copyWith(
                            color: prego.colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (childSession != null)
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

  Widget _statusIcon({required SessionStatus? status, required PregoDesignSystem prego}) => switch (status) {
    SessionStatusBusy() || SessionStatusRetry() => SizedBox(
      width: 16,
      height: 16,
      child: ThrottledActivityIndicator(
        strokeWidth: 2,
        color: prego.colors.bgBrandSolid,
      ),
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

  /// Try to find the child session that matches this subtask part.
  ///
  /// Uses multi-strategy matching: exact → case-insensitive → contains.
  /// If no match found, returns null.
  Session? _findChildSession() {
    if (children.isEmpty) return null;
    // If there's only one child, it's likely the one.
    if (children.length == 1) return children.first;

    final desc = part.description ?? part.prompt;
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
