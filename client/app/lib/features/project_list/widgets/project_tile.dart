part of "../project_list_screen.dart";

/// A single project row in the connected project list.
class _ProjectTile extends StatelessWidget {
  final Project project;
  final int activeSessions;
  final bool unseen;
  final VoidCallback? onLongPress;

  const _ProjectTile({
    required this.project,
    required this.activeSessions,
    this.unseen = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    // Display the live directory; the id is a stable handle that may point
    // where the folder used to be before a move.
    final displayPath = _projectDisplayPath(project);
    final lastSegment = _projectDirectoryBasename(project);
    final displayName = project.name ?? (lastSegment.isNotEmpty ? lastSegment : loc.projectListDefaultName);
    final updatedAt = project.time?.updated;
    final isActive = activeSessions > 0;
    // The project's folder was moved or deleted on disk. Surface it as broken
    // and block navigation so we don't drive into a dead path; Hide/Rename stay
    // available via long-press.
    final missing = project.directoryMissing;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: missing ? prego.colors.bgErrorPrimary : prego.colors.bgBrandSolid,
        child: Icon(
          missing ? Icons.folder_off_outlined : Icons.folder_outlined,
          color: missing ? prego.colors.fgErrorPrimary : prego.colors.fgWhite,
        ),
      ),
      title: Text(
        displayName,
        style: (unseen ? prego.textTheme.textMd.bold : prego.textTheme.textMd.regular).copyWith(
          color: missing ? prego.colors.textSecondary : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            displayPath,
            style: prego.textTheme.textXs.regular,
            maxLines: 1,
            overflow: .ellipsis,
          ),
          if (missing)
            Text(
              loc.projectFolderMissing,
              style: prego.textTheme.textXs.regular.copyWith(
                color: prego.colors.fgErrorPrimary,
              ),
            )
          else ...[
            if (updatedAt != null)
              Text(
                loc.projectListUpdated(context.formatTimestamp(updatedAt)),
                style: prego.textTheme.textXs.regular.copyWith(
                  color: prego.colors.textSecondary,
                ),
              ),
            if (isActive)
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: prego.colors.bgBrandSolid),
                  const SizedBox(width: 4),
                  Text(
                    loc.projectListActiveSessions(activeSessions),
                    style: prego.textTheme.textXs.regular.copyWith(
                      color: prego.colors.bgBrandSolid,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
      isThreeLine: missing || updatedAt != null || isActive,
      trailing: missing
          ? Icon(Icons.error_outline, color: prego.colors.fgErrorPrimary)
          : switch (unseen) {
              true => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 10, color: prego.colors.bgBrandSolid),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              false => const Icon(Icons.chevron_right),
            },
      onTap: () {
        if (missing) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.projectFolderMissingMessage),
              duration: kSnackBarDuration,
            ),
          );
          return;
        }
        context.read<ProjectListCubit>().setActiveProject(project);
        context.pushRoute(
          AppRoute.sessions(projectId: project.id, projectName: displayName),
        );
      },
      onLongPress: onLongPress,
    );
  }
}
