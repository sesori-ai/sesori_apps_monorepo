part of "../project_list_screen.dart";

/// Shown when the bridge is connected but the project list is empty.
/// Intentionally lightweight pending a later redesign.
class _ConnectedEmptyView extends StatelessWidget {
  final VoidCallback onAddProject;

  const _ConnectedEmptyView({required this.onAddProject});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final zyra = context.zyra;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder_off_outlined,
                  size: 48,
                  color: zyra.colors.borderPrimary,
                ),
                const SizedBox(height: 16),
                Text(loc.noProjects, style: zyra.textTheme.textMd.bold.copyWith(color: zyra.colors.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  loc.addProjectPrompt,
                  style: zyra.textTheme.textSm.regular.copyWith(color: zyra.colors.textSecondary),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onAddProject,
                  icon: const Icon(Icons.add),
                  label: Text(loc.addProject),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
