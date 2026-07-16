import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/extensions/build_context_x.dart";
import "../../l10n/app_localizations.dart";
import "session_list_content.dart";
import "session_tile.dart";

class SessionListPanel extends StatelessWidget {
  final String? projectName;
  final String? selectedSessionId;
  final ValueChanged<Session> onSessionTap;
  final SessionMenuEntriesBuilder sessionMenuEntries;
  final ValueChanged<Session> onSessionArchive;
  final ValueChanged<Session> onSessionDelete;
  final ValueChanged<Session> onSessionToggleUnread;
  final VoidCallback onNewSession;
  final VoidCallback? onBack;

  const SessionListPanel({
    super.key,
    this.projectName,
    this.selectedSessionId,
    required this.onSessionTap,
    required this.sessionMenuEntries,
    required this.onSessionArchive,
    required this.onSessionDelete,
    required this.onSessionToggleUnread,
    required this.onNewSession,
    this.onBack,
  });

  /// Header width below which the labelled "New session" button collapses to an
  /// icon-only button so the title keeps a usable width.
  ///
  /// This panel only ever renders in the wide split layout's list pane, whose
  /// width is floored at 320pt (`minListPanelWidth`). Desktop has no
  /// display-cutout safe area, so its pane never drops below that floor — the
  /// header stays ≥ 288pt, above this threshold — and the label is preserved
  /// exactly as before at every desktop window size. Only a notched phone in
  /// landscape, where the safe-area inset shrinks the pane to ~226pt, falls
  /// below it; there back + archive + a labelled button would otherwise overrun
  /// the row and crush the title to zero width.
  static const double _compactHeaderWidth = 280;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<SessionListCubit>().state;
    final showArchived = state is SessionListLoaded && state.showArchived;
    final baseBranch = state is SessionListLoaded ? state.baseBranch : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Lay the header out against its own width so the action button
              // can collapse to an icon when the pane is narrow. Without this,
              // the labelled button + back + archive overrun a landscape split
              // pane, starving the title to zero width — it then wraps one glyph
              // per line and overflows the row both across and down.
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < _compactHeaderWidth;
                  return Row(
                    children: [
                      if (onBack != null)
                        BackButton(
                          onPressed: onBack,
                        ),
                      Expanded(
                        child: Text(
                          _title(loc: loc),
                          style: context.prego.textTheme.textMd.bold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(showArchived ? Icons.archive : Icons.archive_outlined),
                        tooltip: loc.sessionListToggleArchived,
                        onPressed: state is SessionListLoaded
                            ? () => context.read<SessionListCubit>().toggleArchived()
                            : null,
                      ),
                      const SizedBox(width: 8),
                      // Same action and icon in both layouts (tests and muscle
                      // memory target the add icon); only the label drops when
                      // compact, with the tooltip carrying its meaning instead.
                      if (compact)
                        IconButton.filled(
                          icon: const Icon(Icons.add),
                          tooltip: loc.sessionListNewSession,
                          onPressed: onNewSession,
                        )
                      else
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: onNewSession,
                          icon: const Icon(Icons.add),
                          label: Text(loc.sessionListNewSession),
                        ),
                    ],
                  );
                },
              ),
              if (baseBranch != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 2),
                  child: Text(
                    baseBranch,
                    style: context.prego.textTheme.textXs.regular.copyWith(
                      color: context.prego.colors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildScrollableContent(context, state: state)),
      ],
    );
  }

  /// Hosts the sliver-based [SessionListContent] in the pane's own scroll view.
  /// Mirrors the original content behaviour: an `isRefreshing` progress bar and
  /// pull-to-refresh (only once the list has loaded).
  Widget _buildScrollableContent(BuildContext context, {required SessionListState state}) {
    final isRefreshing = state is SessionListLoaded && state.isRefreshing;
    Widget scrollView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (isRefreshing) const SliverToBoxAdapter(child: LinearProgressIndicator()),
        SessionListContent(
          projectName: projectName,
          selectedSessionId: selectedSessionId,
          onSessionTap: onSessionTap,
          sessionMenuEntries: sessionMenuEntries,
          onSessionArchive: onSessionArchive,
          onSessionDelete: onSessionDelete,
          onSessionToggleUnread: onSessionToggleUnread,
        ),
      ],
    );
    if (state is SessionListLoaded) {
      scrollView = RefreshIndicator(
        onRefresh: () => refreshSessionList(context),
        child: scrollView,
      );
    }
    return scrollView;
  }

  String _title({required AppLocalizations loc}) => switch (projectName) {
    final name? => loc.sessionListTitleWithName(name),
    null => loc.sessionListTitle,
  };
}
