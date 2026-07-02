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
    final lastSegment = project.id.split("/").last;
    final displayName = project.name ?? (lastSegment.isNotEmpty ? lastSegment : loc.projectListDefaultName);
    final updatedAt = project.time?.updated;
    final isActive = activeSessions > 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: prego.colors.bgBrandSolid,
        child: Icon(
          Icons.folder_outlined,
          color: prego.colors.fgWhite,
        ),
      ),
      title: Text(
        displayName,
        style: unseen ? prego.textTheme.textMd.bold : null,
      ),
      subtitle: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            project.id,
            style: prego.textTheme.textXs.regular,
            maxLines: 1,
            overflow: .ellipsis,
          ),
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
      ),
      isThreeLine: updatedAt != null || isActive,
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        context.read<ProjectListCubit>().setActiveProject(project);
        context.pushRoute(
          AppRoute.sessions(projectId: project.id, projectName: displayName),
        );
      },
      onLongPress: onLongPress,
    );
  }
}
