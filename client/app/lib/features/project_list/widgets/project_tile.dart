part of "../project_list_screen.dart";

/// A single project row in the connected project list.
///
/// Tapping opens the project's sessions. Long-pressing opens the row's actions
/// — rename, hide — in a [PregoAnchorMenu] anchored to the row, so the project
/// being acted on stays visible beside the menu instead of being covered by a
/// bottom sheet.
///
/// The menu is forced flat on every platform ([PregoAnchorMenu.flat]), like the
/// onboarding support menu ([_NeedHelpMenu]): the glass popup morphs out of its
/// trigger's bounds, which for a full-width row reads as the row collapsing into
/// a small panel, and it allocates a ticker, a scroll controller and an
/// unaspected MediaQuery dependency for every realised row of the list.
class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.activeSessions,
    required this.unseen,
  });

  final Project project;
  final int activeSessions;
  final bool unseen;

  /// Wide enough for the longest action label without the panel spanning the
  /// row it is anchored to.
  static const double _menuWidth = 200;

  @override
  Widget build(BuildContext context) {
    return PregoAnchorMenu(
      flat: true,
      menuWidth: _menuWidth,
      // While the menu is open the rest of the list blurs back and this row
      // stays sharp, so which project the actions will hit is unambiguous.
      spotlight: PregoMenuSpotlight.listRow,
      entriesBuilder: () => _actionEntries(context: context),
      triggerBuilder: (context, openMenu) => _buildRow(context: context, onLongPress: openMenu),
    );
  }

  /// The long-press actions for this project. [PregoAnchorMenu] dismisses the
  /// menu before running an entry's `onTap`, so both of these act against the
  /// still-mounted tile rather than a popped route.
  List<PregoMenuEntry> _actionEntries({required BuildContext context}) {
    final loc = context.loc;
    return [
      PregoMenuItem(
        leadingIcon: TablerRegular.pencil,
        title: loc.rename,
        subtitle: null,
        isSelected: false,
        onTap: () => _rename(context: context),
      ),
      PregoMenuItem(
        leadingIcon: TablerRegular.eye_off,
        title: loc.hideProject,
        subtitle: null,
        isSelected: false,
        onTap: () => _hide(context: context),
      ),
    ];
  }

  void _rename({required BuildContext context}) {
    showRenameProjectDialog(
      context: context,
      project: project,
      cubit: context.read<ProjectListCubit>(),
    );
  }

  /// Hiding drops the project from the list, which disposes this tile — so the
  /// messenger is resolved before the cubit call, not after it.
  void _hide({required BuildContext context}) {
    final messenger = ScaffoldMessenger.of(context);
    final loc = context.loc;
    context.read<ProjectListCubit>().hideProject(project.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text(loc.projectHidden),
        duration: kSnackBarDuration,
      ),
    );
  }

  Widget _buildRow({required BuildContext context, required VoidCallback onLongPress}) {
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
