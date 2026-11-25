import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "pull_request_watches_list.dart";

/// The watched pull requests as a page over the main pane, for the desktop
/// sidebar's row. It reads the session scope's list cubit.
class const PullRequestWatchesPage({
  super.key,
  required final VoidCallback onExit,
  required final OpenPullRequestWatchSession onOpenSession,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return PregoGlassScaffold(
      title: loc.pullRequestWatchesTitle,
      titleMode: PregoTopNavigationTitleMode.inline,
      onBack: null,
      automaticallyImplyLeading: false,
      actions: [
        PregoButtonsIconGlass(
          key: const Key("pull-request-watches-close"),
          icon: TablerRegular.x,
          semanticLabel: loc.pullRequestWatchesClose,
          onPressed: onExit,
        ),
      ],
      onRefresh: () => context.read<PullRequestWatchListCubit>().refresh(),
      slivers: [
        SliverPadding(
          padding: EdgeInsetsDirectional.fromSTEB(
            PregoSpacing.xl,
            0,
            PregoSpacing.xl,
            PregoSpacing.xl + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: SliverToBoxAdapter(
            child: PullRequestWatchesList(sessionId: null, onOpenSession: onOpenSession),
          ),
        ),
      ],
      titleKeptSuffix: null,
    );
  }
}
