import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../../core/di/injection.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/app_modal_bottom_sheet.dart";
import "../../../l10n/app_localizations.dart";
import "branch_picker_selection_panel.dart";

/// Result returned by [BranchPickerSheet] when a selection is confirmed.
typedef BranchPickerResult = ({WorktreeMode mode, String? branch});

/// Bottom sheet for selecting a branch and worktree mode.
///
/// Shows a search bar, a "use project directory" entry, and a list of
/// available branches. After selecting a branch the user picks a mode
/// (stay on branch or create new branch from it).
class BranchPickerSheet extends StatelessWidget {
  final String projectId;

  const BranchPickerSheet({super.key, required this.projectId});

  /// Shows the branch picker as a modal bottom sheet.
  /// Returns the selected [BranchPickerResult], or `null` if dismissed.
  static Future<BranchPickerResult?> show(
    BuildContext context, {
    required String projectId,
  }) {
    return showAppModalBottomSheet<BranchPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height * 0.7;
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: BranchPickerSheet(projectId: projectId),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BranchListCubit(
        projectRepository: getIt<ProjectRepository>(),
        projectId: projectId,
      ),
      child: const _BranchPickerBody(),
    );
  }
}

class _BranchPickerBody extends StatelessWidget {
  const _BranchPickerBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;
    final state = context.watch<BranchListCubit>().state;

    return Column(
      children: [
        Center(
          child: Container(
            margin: const EdgeInsetsDirectional.only(top: 12, bottom: 8),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(loc.branchPickerTitle, style: theme.textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            autofocus: false,
            decoration: InputDecoration(
              hintText: loc.branchPickerSearch,
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
            ),
            onChanged: (value) => context.read<BranchListCubit>().search(query: value),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: switch (state) {
            BranchListLoading() => const Center(child: CircularProgressIndicator()),
            BranchListError(:final message) => Center(child: Text(message)),
            BranchListLoaded() => _BranchList(state: state),
          },
        ),
        if (state case BranchListLoaded(:final selectedBranch) when selectedBranch != null)
          BranchPickerSelectionPanel(
            state: state,
            onModeSelected: (mode) => context.read<BranchListCubit>().selectMode(mode: mode),
            onConfirm: () => context.pop<BranchPickerResult>(
              (mode: state.selectedMode!, branch: state.selectedBranch!.name),
            ),
          ),
      ],
    );
  }
}

class _BranchList extends StatelessWidget {
  final BranchListLoaded state;

  const _BranchList({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: state.filteredBranches.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _ProjectDirTile(currentBranch: state.currentBranch);
        }
        final branch = state.filteredBranches[index - 1];
        final isSelected = state.selectedBranch?.name == branch.name;
        final loc = context.loc;

        return ListTile(
          dense: true,
          title: Text(
            branch.name,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: _buildSubtitle(branch: branch, loc: loc),
          leading: isSelected
              ? Icon(Icons.radio_button_checked, color: theme.colorScheme.primary)
              : Icon(Icons.radio_button_unchecked, color: theme.colorScheme.outline),
          trailing: branch.isRemoteOnly
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    loc.branchPickerRemote,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                )
              : null,
          onTap: () => context.read<BranchListCubit>().selectBranch(branch: branch),
        );
      },
    );
  }

  Widget? _buildSubtitle({
    required BranchInfo branch,
    required AppLocalizations loc,
  }) {
    final timestamp = branch.lastCommitTimestamp;
    if (timestamp == null) return null;

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final diff = DateTime.now().difference(date);
    final timeAgo = switch (diff) {
      Duration(inDays: > 365) => "${diff.inDays ~/ 365}y",
      Duration(inDays: > 30) => "${diff.inDays ~/ 30}mo",
      Duration(inDays: > 0) => "${diff.inDays}d",
      Duration(inHours: > 0) => "${diff.inHours}h",
      Duration(inMinutes: > 0) => "${diff.inMinutes}m",
      _ => "now",
    };
    return Text(loc.branchPickerTimeAgo(timeAgo));
  }
}

class _ProjectDirTile extends StatelessWidget {
  final String? currentBranch;

  const _ProjectDirTile({required this.currentBranch});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;

    return ListTile(
      dense: true,
      title: Text(
        loc.branchPickerProjectDir,
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: currentBranch != null
          ? Text(loc.branchPickerProjectDirSubtitle(currentBranch!))
          : Text(loc.branchPickerNoWorktree),
      leading: Icon(Icons.folder_outlined, color: theme.colorScheme.primary),
      onTap: () => context.pop<BranchPickerResult>(
        (mode: WorktreeMode.none, branch: null),
      ),
    );
  }
}
