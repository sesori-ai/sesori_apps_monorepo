import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../widgets/pull_request_watch_look.dart";
import "../project_list/project_path_labels.dart";
import "../session_list/session_list_headings.dart";

typedef OpenPullRequestWatchSession = void Function({
  required String projectId,
  required String? projectName,
  required String sessionId,
  required String? sessionTitle,
});

/// Shows the computer's watched pull requests over the current page, only
/// [sessionId]'s when it is set. A row opens its session after the sheet
/// closes.
Future<void> showPullRequestWatchesSheet({
  required BuildContext context,
  required String? sessionId,
  required OpenPullRequestWatchSession onOpenSession,
}) {
  final watches = context.read<PullRequestWatchListCubit>();
  final projects = context.read<ProjectListCubit>();
  return showPregoModal<void>(
    context: context,
    title: context.loc.pullRequestWatchesTitle,
    builder: (sheetContext) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: watches),
        BlocProvider.value(value: projects),
      ],
      child: PullRequestWatchesList(
        sessionId: sessionId,
        onOpenSession: ({required projectId, required projectName, required sessionId, required sessionTitle}) {
          // ignore: no_slop_linter/avoid_navigator_of, pops the pageless sheet route this function pushed
          Navigator.of(sheetContext).pop();
          onOpenSession(
            projectId: projectId,
            projectName: projectName,
            sessionId: sessionId,
            sessionTitle: sessionTitle,
          );
        },
      ),
    ),
  );
}

/// The watched pull requests under Needs you, Waiting, Ready and Merged
/// today. While it stays open a row keeps its group and place and only its
/// content changes; it regroups the next time it opens. Swiping a row offers
/// Auto-merge and Stop, which a long press also lists.
class const PullRequestWatchesList({
  super.key,

  /// Lists only this session's watches when set.
  required final String? sessionId,
  required final OpenPullRequestWatchSession onOpenSession,
}) extends StatefulWidget {
  @override
  State<PullRequestWatchesList> createState() => _PullRequestWatchesListState();
}

class _PullRequestWatchesListState() extends State<PullRequestWatchesList> {
  /// The sections as this list last showed them.
  List<PullRequestWatchSection>? _shown;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<PullRequestWatchListCubit>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return switch (context.watch<PullRequestWatchListCubit>().state) {
      PullRequestWatchListLoading() => const Padding(
        padding: EdgeInsets.all(PregoSpacing.xl),
        child: Center(child: PregoActivityIndicator(color: null)),
      ),
      PullRequestWatchListFailed() => PregoGroupedRows(
        children: [
          PregoGroupedRow(
            key: const Key("pull-request-watches-failed"),
            icon: TablerRegular.alert_circle,
            title: Text(loc.pullRequestWatchesLoadFailed),
            trailing: PregoButtonsSolid(
              label: loc.pullRequestWatchesRetry,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.sm,
              onPressed: () => unawaited(context.read<PullRequestWatchListCubit>().retry()),
            ),
          ),
        ],
      ),
      PullRequestWatchListUnsupported() => _Note(
        key: const Key("pull-request-watches-unsupported"),
        text: loc.pullRequestWatchesUnsupported,
      ),
      PullRequestWatchListLoaded(:final watches, :final stopping) => _sections(
        context: context,
        watches: watches,
        stopping: stopping,
      ),
    };
  }

  Widget _sections({
    required BuildContext context,
    required List<PullRequestWatchListItem> watches,
    required Set<PullRequestWatchKey> stopping,
  }) {
    final sections = arrangePullRequestWatches(watches: watches, sessionId: widget.sessionId, shown: _shown);
    _shown = sections;
    final loc = context.loc;
    return AnimatedSize(
      duration: context.isReducedMotion ? Duration.zero : pregoAnimatedListItemDuration,
      curve: Curves.easeOut,
      alignment: AlignmentDirectional.topStart,
      child: sections.isEmpty
          ? _Note(key: const Key("pull-request-watches-empty"), text: loc.pullRequestWatchesEmpty)
          : PregoAnimatedList<PullRequestWatchSection>(
              items: sections,
              itemKey: (section) => ValueKey(section.group),
              itemBuilder: (context, index, section) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SessionListHeading(
                    heading: _heading(context: context, group: section.group),
                    isFirst: index == 0,
                    action: null,
                  ),
                  PregoGroupedRows(
                    children: [
                      PregoAnimatedList<PullRequestWatchListItem>(
                        items: section.watches,
                        itemKey: (item) => ValueKey(item.key),
                        itemBuilder: (context, index, item) => PregoGroupedRowPosition(
                          isLast: index == section.watches.length - 1,
                          child: _WatchRow(
                            item: item,
                            stopping: stopping.contains(item.key),
                            onOpenSession: widget.onOpenSession,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  static String _heading({required BuildContext context, required PullRequestWatchGroup group}) {
    final loc = context.loc;
    return switch (group) {
      PullRequestWatchGroup.needsYou => loc.pullRequestWatchesGroupNeedsYou,
      PullRequestWatchGroup.waiting => loc.pullRequestWatchesGroupWaiting,
      PullRequestWatchGroup.ready => loc.pullRequestWatchesGroupReady,
      PullRequestWatchGroup.mergedToday => loc.pullRequestWatchesGroupMergedToday,
    };
  }
}

class const _Note({super.key, required final String text}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: PregoSpacing.xl),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
    ),
  );
}

/// One watched pull request: its status glyph, its title, its repository,
/// number and status with an auto-merge mark, and the session watching it.
class const _WatchRow({
  required final PullRequestWatchListItem item,
  required final bool stopping,
  required final OpenPullRequestWatchSession onOpenSession,
}) extends StatelessWidget {
  static const double _menuWidth = 220;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final watch = item.watch;
    final merged = watch.status is PullRequestWatchStatusMerged;
    return PregoSwipeActions(
      key: Key("pull-request-watch-${item.sessionId}-${watch.repository}#${watch.number}"),
      // A merged pull request has nothing left to merge.
      actionsBuilder: (context, close) => [
        if (!merged)
          _pill(
            label: watch.autoMerge ? loc.pullRequestWatchAutoMergeOff : loc.pullRequestWatchAutoMergeOn,
            icon: TablerRegular.arrows_join,
            type: PregoButtonsSolidType.success,
            close: close,
            onPressed: () => _setAutoMerge(context: context, enabled: !watch.autoMerge),
          ),
      ],
      primaryActionBuilder: (context, close) => _pill(
        label: loc.pullRequestWatchStop,
        icon: TablerRegular.eye_off,
        type: PregoButtonsSolidType.destructive,
        close: close,
        onPressed: () => _stop(context: context),
      ),
      onFullSwipe: () => _stop(context: context),
      child: PregoContextMenu(
        menuWidth: _menuWidth,
        spotlight: PregoMenuSpotlight.listRow,
        onOpenChanged: null,
        entriesBuilder: () => [
          if (!merged)
            PregoMenuItem(
              leadingIcon: TablerRegular.arrows_join,
              title: watch.autoMerge ? loc.pullRequestWatchAutoMergeOff : loc.pullRequestWatchAutoMergeOn,
              subtitle: null,
              isSelected: false,
              shortcutLabel: null,
              onTap: () => _setAutoMerge(context: context, enabled: !watch.autoMerge),
            ),
          PregoMenuItem(
            leadingIcon: TablerRegular.eye_off,
            title: loc.pullRequestWatchStop,
            subtitle: null,
            isSelected: false,
            shortcutLabel: null,
            onTap: () => _stop(context: context),
          ),
        ],
        builder: (context, menuOpen) => _content(context: context),
      ),
    );
  }

  Widget _content({required BuildContext context}) {
    final prego = context.prego;
    final loc = context.loc;
    final watch = item.watch;
    final look = pullRequestWatchLook(context: context, status: watch.status);
    final words = switch (watch.status) {
      PullRequestWatchStatusNeedsYou(:final reasons) when reasons.isNotEmpty => [
        for (final reason in reasons) _needWords(context: context, need: reason),
      ].join(", "),
      _ => look.words,
    };
    final duration = context.isReducedMotion ? Duration.zero : pregoAnimatedListItemDuration;
    final secondary = prego.colors.textSecondary;
    return PregoGroupedRow(
      leading: SizedBox(
        width: 20,
        child: AnimatedSwitcher(
          duration: duration,
          child: stopping
              ? const SizedBox.square(
                  key: ValueKey("stopping"),
                  dimension: 20,
                  child: PregoActivityIndicator(color: null),
                )
              : Icon(
                  _glyph(status: watch.status),
                  key: ValueKey(watch.status.runtimeType),
                  size: 20,
                  color: look.color,
                ),
        ),
      ),
      leadingWidth: 20,
      title: Text(watch.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            spacing: PregoSpacing.xs,
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: "${watch.repository}#${watch.number} · "),
                      TextSpan(
                        text: words,
                        style: TextStyle(color: look.color),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AnimatedSize(
                duration: duration,
                curve: Curves.easeOut,
                child: AnimatedSwitcher(
                  duration: duration,
                  child: watch.autoMerge
                      ? Row(
                          key: const Key("pull-request-watch-auto-merge-mark"),
                          mainAxisSize: MainAxisSize.min,
                          spacing: PregoSpacing.xxs,
                          children: [
                            Icon(
                              TablerRegular.arrows_join,
                              size: PregoIconSize.sm,
                              color: prego.colors.textSuccessPrimary,
                            ),
                            Text(
                              loc.pullRequestWatchAutoMergeMark,
                              style: TextStyle(color: prego.colors.textSuccessPrimary),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
          Row(
            spacing: PregoSpacing.xs,
            children: [
              Icon(TablerRegular.message_circle, size: PregoIconSize.sm, color: secondary),
              Flexible(
                child: Text(
                  item.sessionTitle ?? loc.sessionListUntitled,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () => onOpenSession(
        projectId: item.projectId,
        projectName: switch (_listedProject(context: context, projectId: item.projectId)) {
          final project? => projectDisplayName(loc: loc, project: project),
          null => null,
        },
        sessionId: item.sessionId,
        sessionTitle: item.sessionTitle,
      ),
    );
  }

  Future<void> _setAutoMerge({required BuildContext context, required bool enabled}) async {
    final presenter = PregoPopupAlertPresenter.of(context);
    final message = context.loc.pullRequestWatchAutoMergeFailed;
    final changed = await context.read<PullRequestWatchListCubit>().setAutoMerge(item: item, enabled: enabled);
    if (!changed) presenter.show(title: message, variant: PregoPopupAlertsNotificationsVariant.error);
  }

  Future<void> _stop({required BuildContext context}) async {
    final presenter = PregoPopupAlertPresenter.of(context);
    final message = context.loc.sessionPullRequestWatchStopFailed;
    final stopped = await context.read<PullRequestWatchListCubit>().stop(item: item);
    if (!stopped) presenter.show(title: message, variant: PregoPopupAlertsNotificationsVariant.error);
  }

  static Widget _pill({
    required String label,
    required IconData icon,
    required PregoButtonsSolidType type,
    required VoidCallback close,
    required Future<void> Function() onPressed,
  }) => PregoButtonsSolid(
    label: label,
    leadingIcon: icon,
    hierarchy: PregoButtonsSolidHierarchy.primary,
    type: type,
    size: PregoButtonsSolidSize.md,
    onPressed: () {
      close();
      unawaited(onPressed());
    },
  );

  static IconData _glyph({required PullRequestWatchStatus status}) => switch (status) {
    PullRequestWatchStatusNeedsYou() => TablerRegular.alert_circle,
    PullRequestWatchStatusWaiting() => TablerRegular.clock,
    PullRequestWatchStatusReady() => TablerRegular.circle_check,
    PullRequestWatchStatusMerged() => TablerRegular.git_merge,
    PullRequestWatchStatusUnknown() => TablerRegular.git_pull_request,
  };

  static String _needWords({required BuildContext context, required PullRequestWatchNeed need}) {
    final loc = context.loc;
    return switch (need) {
      PullRequestWatchNeed.ciFailing => loc.pullRequestWatchNeedCiFailing,
      PullRequestWatchNeed.conflict => loc.pullRequestWatchNeedConflict,
      PullRequestWatchNeed.newReviewComments => loc.pullRequestWatchNeedNewReviewComments,
      PullRequestWatchNeed.readyWithoutAutoMerge => loc.pullRequestWatchNeedReadyWithoutAutoMerge,
      PullRequestWatchNeed.unknown => loc.pullRequestWatchStatusNeedsYou,
    };
  }

  static ProjectSummary? _listedProject({required BuildContext context, required String projectId}) =>
      switch (context.read<ProjectListCubit>().state) {
        ProjectListLoaded(:final projects) => projects.where((project) => project.id == projectId).firstOrNull,
        ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => null,
      };
}
