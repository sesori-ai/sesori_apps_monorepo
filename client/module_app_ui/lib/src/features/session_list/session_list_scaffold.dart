import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../widgets/catalog_scan_row.dart";
import "../../widgets/project_nav_subtitle.dart";
import "session_list_action_dispatcher.dart";
import "session_list_content.dart";
import "session_tile.dart";

class const SessionListScaffold({
  super.key,
  final String? projectName,
  final String? selectedSessionId,
  required final SessionOpenedCallback? onSessionTap,
  required final SessionListActionDispatcher actionDispatcher,
  required final Widget archivedEmptyState,
  required final VoidCallback? onNewSession,
  required final VoidCallback? onBack,
  required final Widget? connectionBanner,
}) extends StatelessWidget {
  static const double _newTaskButtonBaseClearance = 96;

  /// The default reservation matches the project list's spacing. The xl
  /// button's label stays on one line, but its line box grows under accessibility
  /// text scaling, so add that growth without increasing the default gap.
  static double _newTaskButtonClearance({required BuildContext context}) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final textStyle = context.prego.textTheme.textMd.bold;
    final fontSize = textStyle.fontSize;
    if (fontSize == null) return bottomInset + _newTaskButtonBaseClearance;

    final heightMultiplier = textStyle.height ?? 1;
    final unscaledLabelHeight = fontSize * heightMultiplier;
    final scaledLabelHeight = MediaQuery.textScalerOf(context).scale(fontSize) * heightMultiplier;
    final labelGrowth = scaledLabelHeight > unscaledLabelHeight ? scaledLabelHeight - unscaledLabelHeight : 0.0;

    return bottomInset + _newTaskButtonBaseClearance + labelGrowth;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<SessionListCubit>().state;
    final showArchived = state is SessionListLoaded && state.showArchived;
    final isRefreshing = state is SessionListLoaded && state.isRefreshing;
    final catalogScan = state is SessionListLoaded ? state.catalogScan : const CatalogRescanState.idle();

    return PregoGlassScaffold(
      // The sessions route sits at the base of the nested pane navigator, so
      // the bar cannot imply a back button — the poppable route lives on the
      // root navigator. Render it explicitly from the injected callback.
      onBack: onBack,
      // The bar's back-leading block identifies context: the project name over
      // the repository slug of its git remote.
      title: projectName ?? loc.sessionListTitle,
      titleMode: PregoTopNavigationTitleMode.backLeading,
      subtitle: buildProjectNavSubtitle(context),
      banner: connectionBanner,
      actions: [
        PregoButtonsIconGlass(
          icon: TablerRegular.archive,
          // Tint when the archived filter is active (Tabler has no filled
          // variant), replacing the old filled/outlined Material toggle.
          iconColor: showArchived ? context.prego.colors.bgBrandSolid : null,
          semanticLabel: loc.sessionListToggleArchived,
          onPressed: () {
            final cubit = context.read<SessionListCubit>();
            if (cubit.state is SessionListLoaded) {
              cubit.toggleArchived();
            }
          },
        ),
      ],
      floatingActionButton: onNewSession == null
          ? null
          : PregoButtonsSolid(
              label: loc.sessionListNewTask,
              leadingIcon: TablerRegular.plus,
              hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
              size: PregoButtonsSolidSize.xl,
              onPressed: onNewSession,
            ),
      // Pull-to-refresh only makes sense once the list has loaded.
      onRefresh: state is SessionListLoaded ? () => refreshSessionList(context) : null,
      deepRefresh: state is SessionListLoaded
          ? CatalogScanRow.deepRefresh(
              context: context,
              onStart: () => context.read<SessionListCubit>().startCatalogScan(),
            )
          : null,
      slivers: [
        if (isRefreshing) const SliverToBoxAdapter(child: LinearProgressIndicator()),
        SliverToBoxAdapter(
          child: CatalogScanRow(
            scan: catalogScan,
            onCancel: () => context.read<SessionListCubit>().cancelCatalogScan(),
            onDismiss: () => context.read<SessionListCubit>().dismissCatalogScan(),
          ),
        ),
        SessionListContent(
          projectName: projectName,
          selectedSessionId: selectedSessionId,
          onSessionTap: onSessionTap,
          actionDispatcher: actionDispatcher,
          archivedEmptyState: archivedEmptyState,
        ),
        if (onNewSession != null && state is SessionListLoaded && state.sessions.isNotEmpty)
          // Clear the floating new-task button and the home indicator.
          SliverToBoxAdapter(
            child: SizedBox(height: _newTaskButtonClearance(context: context)),
          ),
      ],
    );
  }
}
