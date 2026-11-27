import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../platform/external_link_opener.dart";
import "../../widgets/pull_request_watch_look.dart";
import "../project_list/project_path_labels.dart";
import "../session_list/session_list_headings.dart";
import "pull_request_watch_detail.dart";

typedef OpenPullRequestWatchSession = void Function({
  required String projectId,
  required String? projectName,
  required String sessionId,
  required String? sessionTitle,
});

/// Shows the computer's watched pull requests over the current page, only
/// [sessionId]'s when it is set. A row opens its detail card, whose Go to
/// session closes both and opens the session; without [onOpenSession], from
/// inside the session, the card has no Go to session.
Future<void> showPullRequestWatchesSheet({
  required BuildContext context,
  required String? sessionId,
  required ExternalLinkOpener openExternalLink,
  required OpenPullRequestWatchSession? onOpenSession,
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
        openExternalLink: openExternalLink,
        onOpenSession: switch (onOpenSession) {
          final open? => ({required projectId, required projectName, required sessionId, required sessionTitle}) {
            // ignore: no_slop_linter/avoid_navigator_of, pops the pageless sheet route this function pushed
            Navigator.of(sheetContext).pop();
            open(projectId: projectId, projectName: projectName, sessionId: sessionId, sessionTitle: sessionTitle);
          },
          null => null,
        },
      ),
    ),
  );
}

/// The watched pull requests in the modal, as tall as they need up to most of
/// the screen, then scrolling. The rows are built as they scroll into view.
class const PullRequestWatchesList({
  super.key,

  /// Lists only this session's watches when set.
  required final String? sessionId,
  required final ExternalLinkOpener openExternalLink,

  /// Opens a watch's session; null inside that session.
  required final OpenPullRequestWatchSession? onOpenSession,
}) extends StatelessWidget {
  static const double _maxHeightFraction = 0.7;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: context.isReducedMotion ? Duration.zero : pregoAnimatedListItemDuration,
    curve: Curves.easeOut,
    alignment: AlignmentDirectional.topStart,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.heightOf(context) * _maxHeightFraction),
      child: CustomScrollView(
        // The modal's own scroll view owns the primary controller.
        primary: false,
        shrinkWrap: true,
        slivers: [
          PullRequestWatchesSliver(
            sessionId: sessionId,
            openExternalLink: openExternalLink,
            onOpenSession: onOpenSession,
          ),
        ],
      ),
    ),
  );
}

/// The watched pull requests under To merge, Agent on it, Waiting, Merges
/// automatically and Merged today, as a sliver built lazily. While it stays
/// open a row keeps its group and place and only its content changes; it
/// regroups the next time it opens. A tap on a row opens its detail card.
class const PullRequestWatchesSliver({
  super.key,

  /// Lists only this session's watches when set.
  required final String? sessionId,
  required final ExternalLinkOpener openExternalLink,

  /// Opens a watch's session; null inside that session.
  required final OpenPullRequestWatchSession? onOpenSession,
}) extends StatefulWidget {
  @override
  State<PullRequestWatchesSliver> createState() => _PullRequestWatchesSliverState();
}

class _PullRequestWatchesSliverState() extends State<PullRequestWatchesSliver> {
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
      PullRequestWatchListLoading() => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(PregoSpacing.xl),
          child: Center(child: PregoActivityIndicator(color: null)),
        ),
      ),
      PullRequestWatchListFailed() => SliverToBoxAdapter(
        child: PregoGroupedRows(
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
      ),
      PullRequestWatchListUnsupported() => SliverToBoxAdapter(
        child: _Note(key: const Key("pull-request-watches-unsupported"), text: loc.pullRequestWatchesUnsupported),
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
    final entries = [
      for (final section in sections) ...[
        _HeadingEntry(group: section.group),
        for (final (index, item) in section.watches.indexed)
          _RowEntry(item: item, isFirst: index == 0, isLast: index == section.watches.length - 1),
      ],
    ];
    // The list stays mounted when the last row leaves, so it closes before
    // the empty note fades in.
    return SliverMainAxisGroup(
      slivers: [
        PregoAnimatedSliverList<_Entry>(
          items: entries,
          slidesWhenMoved: (_) => false,
          itemKey: (entry) => switch (entry) {
            _HeadingEntry(:final group) => ValueKey(group),
            _RowEntry(:final item) => ValueKey(item.key),
          },
          itemBuilder: (context, index, entry) => switch (entry) {
            _HeadingEntry(:final group) => _heading(context: context, group: group, isFirst: index == 0),
            _RowEntry(:final item, :final isFirst, :final isLast) => _CardSegment(
              isFirst: isFirst,
              isLast: isLast,
              child: _WatchRow(
                item: item,
                stopping: stopping.contains(item.key),
                openExternalLink: widget.openExternalLink,
                onOpenSession: widget.onOpenSession,
              ),
            ),
          },
        ),
        if (sections.isEmpty)
          SliverToBoxAdapter(
            // Fades in once departing rows have had time to close.
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: context.isReducedMotion ? Duration.zero : pregoAnimatedListItemDuration * 2,
              curve: const Interval(0.5, 1),
              builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
              child: _Note(key: const Key("pull-request-watches-empty"), text: context.loc.pullRequestWatchesEmpty),
            ),
          ),
      ],
    );
  }

  /// A group's heading; To merge, the only group that needs the user, is
  /// green and leads with the merge glyph.
  static Widget _heading({required BuildContext context, required PullRequestWatchStage group, required bool isFirst}) {
    final loc = context.loc;
    final look = pullRequestWatchLook(context: context, stage: group);
    return SessionListHeading(
      heading: switch (group) {
        PullRequestWatchStage.waiting => loc.pullRequestWatchesGroupWaiting,
        PullRequestWatchStage.mergedToday => loc.pullRequestWatchesGroupMergedToday,
        PullRequestWatchStage.toMerge ||
        PullRequestWatchStage.agentOnIt ||
        PullRequestWatchStage.mergesAutomatically => look.words,
      },
      isFirst: isFirst,
      action: null,
      accent: group == PullRequestWatchStage.toMerge ? (glyph: look.glyph, color: look.color) : null,
    );
  }
}

sealed class const _Entry();

final class const _HeadingEntry({required final PullRequestWatchStage group}) extends _Entry;

final class const _RowEntry({
  required final PullRequestWatchListItem item,
  required final bool isFirst,
  required final bool isLast,
}) extends _Entry;

/// One row's slice of its group's rounded card, so the card is built row by
/// row with the list.
class const _CardSegment({required final bool isFirst, required final bool isLast, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(
      // ignore: no_slop_linter/avoid_interaction_mode_reads, matches PregoGroupedRows' card
      PregoInteractionScope.of(context) == PregoInteractionMode.pointer ? PregoRadius.xl : PregoRadius.x5l,
    );
    return PregoGroupedRowPosition(
      isLast: isLast,
      child: Material(
        color: context.prego.colors.bgSurface3,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.vertical(top: isFirst ? radius : Radius.zero, bottom: isLast ? radius : Radius.zero),
        child: child,
      ),
    );
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

/// One watched pull request: its stage glyph, its title, its repository,
/// number and stage with the agent's reasons or a quiet auto-merge mark, and
/// the session watching it. A tap opens its detail card.
class const _WatchRow({
  required final PullRequestWatchListItem item,
  required final bool stopping,
  required final ExternalLinkOpener openExternalLink,
  required final OpenPullRequestWatchSession? onOpenSession,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: Key("pull-request-watch-${item.sessionId}-${item.watch.repository}#${item.watch.number}"),
    child: _content(context: context),
  );

  Widget _content({required BuildContext context}) {
    final prego = context.prego;
    final loc = context.loc;
    final watch = item.watch;
    final stage = PullRequestWatchStage.of(status: watch.status);
    final look = pullRequestWatchLook(context: context, stage: stage);
    final words = switch (stage) {
      PullRequestWatchStage.waiting when watch.autoMerge => loc.pullRequestWatchStageWaitingThenMerges,
      _ => look.words,
    };
    final reasons = pullRequestWatchAgentReasons(context: context, status: watch.status);
    final strong = switch (stage) {
      PullRequestWatchStage.toMerge || PullRequestWatchStage.agentOnIt => true,
      PullRequestWatchStage.waiting ||
      PullRequestWatchStage.mergesAutomatically ||
      PullRequestWatchStage.mergedToday => false,
    };
    // Waiting says it in words, and merging automatically already means it.
    final autoMergeMark = switch (stage) {
      PullRequestWatchStage.toMerge || PullRequestWatchStage.agentOnIt => watch.autoMerge,
      PullRequestWatchStage.waiting ||
      PullRequestWatchStage.mergesAutomatically ||
      PullRequestWatchStage.mergedToday => false,
    };
    final duration = context.isReducedMotion ? Duration.zero : pregoAnimatedListItemDuration;
    final secondary = prego.colors.textSecondary;
    final tertiary = prego.colors.textTertiary;
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
              : Icon(look.glyph, key: ValueKey(stage), size: 20, color: look.color),
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
                        style: TextStyle(color: look.color, fontWeight: strong ? FontWeight.w500 : null),
                      ),
                      if (reasons != null) TextSpan(text: " · $reasons"),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AnimatedSize(
                duration: duration,
                curve: Curves.easeOut,
                child: AnimatedSwitcher(
                  duration: duration,
                  child: autoMergeMark
                      ? Row(
                          key: const Key("pull-request-watch-auto-merge-mark"),
                          mainAxisSize: MainAxisSize.min,
                          spacing: PregoSpacing.xxs,
                          children: [
                            Icon(TablerRegular.arrows_join, size: PregoIconSize.sm, color: tertiary),
                            Text(loc.pullRequestWatchAutoMergeMark, style: TextStyle(color: tertiary)),
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
      onTap: () => unawaited(
        showPullRequestWatchDetail(
          context: context,
          item: item,
          openExternalLink: openExternalLink,
          onOpenSession: switch (onOpenSession) {
            final open? => () => open(
              projectId: item.projectId,
              projectName: switch (_listedProject(context: context, projectId: item.projectId)) {
                final project? => projectDisplayName(loc: loc, project: project),
                null => null,
              },
              sessionId: item.sessionId,
              sessionTitle: item.sessionTitle,
            ),
            null => null,
          },
          onSetAutoMerge: (enabled) => unawaited(_setAutoMerge(context: context, enabled: enabled)),
          onStop: () => unawaited(_stop(context: context)),
        ),
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

  static ProjectSummary? _listedProject({required BuildContext context, required String projectId}) =>
      switch (context.read<ProjectListCubit>().state) {
        ProjectListLoaded(:final projects) => projects.where((project) => project.id == projectId).firstOrNull,
        ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => null,
      };
}
