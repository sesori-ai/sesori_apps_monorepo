part of "../project_list_screen.dart";

/// A single project row in the connected project list.
class _ProjectTile extends StatelessWidget {
  final Project project;
  final int activeSessions;
  final VoidCallback? onLongPress;

  const _ProjectTile({
    required this.project,
    required this.activeSessions,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final zyra = context.zyra;
    final lastSegment = project.id.split("/").last;
    final displayName = project.name ?? (lastSegment.isNotEmpty ? lastSegment : loc.projectListDefaultName);
    final updatedAt = project.time?.updated;
    final isActive = activeSessions > 0;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: zyra.colors.bgBrandSolid,
        child: Icon(
          Icons.folder_outlined,
          color: zyra.colors.fgWhite,
        ),
      ),
      title: Text(displayName),
      subtitle: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            project.id,
            style: zyra.textTheme.textXs.regular,
            maxLines: 1,
            overflow: .ellipsis,
          ),
          if (updatedAt != null)
            Text(
              loc.projectListUpdated(context.formatTimestamp(updatedAt)),
              style: zyra.textTheme.textXs.regular.copyWith(
                color: zyra.colors.textSecondary,
              ),
            ),
          if (isActive)
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: zyra.colors.bgBrandSolid),
                const SizedBox(width: 4),
                Text(
                  loc.projectListActiveSessions(activeSessions),
                  style: zyra.textTheme.textXs.regular.copyWith(
                    color: zyra.colors.bgBrandSolid,
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
