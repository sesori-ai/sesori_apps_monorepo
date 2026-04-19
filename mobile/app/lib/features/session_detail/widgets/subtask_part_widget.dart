import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/routing/app_router.dart";

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
    final theme = Theme.of(context);
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
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: childSession != null
              ? () {
                  context.pushRoute(
                    AppRoute.sessionDetail(
                      projectId: projectId ?? childSession.projectID,
                      sessionId: childSession.id,
                      readOnly: true,
                      sessionTitle: childSession.title,
                    ),
                  );
                }
              : null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _statusIcon(status: status, theme: theme),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: .ellipsis,
                      ),
                      if (agent != null)
                        Text(
                          agent,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (childSession != null)
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusIcon({required SessionStatus? status, required ThemeData theme}) => switch (status) {
    SessionStatusBusy() => SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: theme.colorScheme.primary,
      ),
    ),
    SessionStatusRetry() => Icon(
      Icons.refresh,
      size: 16,
      color: theme.colorScheme.tertiary,
    ),
    SessionStatusIdle() => Icon(
      Icons.check_circle,
      size: 16,
      color: theme.colorScheme.primary,
    ),
    null => Icon(
      Icons.play_circle_outline,
      size: 16,
      color: theme.colorScheme.outline,
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
