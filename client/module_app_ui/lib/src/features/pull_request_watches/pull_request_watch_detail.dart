import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../platform/external_link_opener.dart";
import "../../widgets/pull_request_watch_look.dart";

/// Shows [item]'s detail card over the list: its stage and every reason in
/// full, and its actions. It follows the list's state while open, so a status
/// or auto-merge change shows in place. Go to session shows only when
/// [onOpenSession] is set, that is outside the session.
Future<void> showPullRequestWatchDetail({
  required BuildContext context,
  required PullRequestWatchListItem item,
  required ExternalLinkOpener openExternalLink,
  required VoidCallback? onOpenSession,
  required ValueChanged<bool> onSetAutoMerge,
  required VoidCallback onStop,
}) {
  final watches = context.read<PullRequestWatchListCubit>();
  return showPregoModal<void>(
    context: context,
    title: item.watch.title,
    builder: (cardContext) {
      // ignore: no_slop_linter/avoid_navigator_of, pops the pageless card route this function pushed
      void close() => Navigator.of(cardContext).pop();
      return BlocProvider.value(
        value: watches,
        child: _PullRequestWatchDetail(
          initial: item,
          onOpenOnGitHub: () => unawaited(
            openExternalLink(url: Uri.parse(item.watch.url), mode: UrlLaunchMode.externalApp).then<void>((_) {}),
          ),
          onOpenSession: switch (onOpenSession) {
            final open? => () {
              close();
              open();
            },
            null => null,
          },
          onSetAutoMerge: onSetAutoMerge,
          onStop: () {
            close();
            onStop();
          },
        ),
      );
    },
  );
}

class const _PullRequestWatchDetail({
  /// The watch as the row showed it, kept once it leaves the list.
  required final PullRequestWatchListItem initial,
  required final VoidCallback onOpenOnGitHub,
  required final VoidCallback? onOpenSession,
  required final ValueChanged<bool> onSetAutoMerge,
  required final VoidCallback onStop,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    final text = prego.textTheme;
    final loc = context.loc;
    final item =
        switch (context.watch<PullRequestWatchListCubit>().state) {
          PullRequestWatchListLoaded(:final watches) => watches.where((watch) => watch.key == initial.key).firstOrNull,
          PullRequestWatchListLoading() || PullRequestWatchListFailed() || PullRequestWatchListUnsupported() => null,
        } ??
        initial;
    final watch = item.watch;
    final stage = PullRequestWatchStage.of(status: watch.status);
    final look = pullRequestWatchLook(context: context, stage: stage);
    final reasons = switch (watch.status) {
      PullRequestWatchStatusNeedsYou(:final reasons) => [
        for (final reason in reasons)
          ?switch (reason) {
            PullRequestWatchNeed.ciFailing => (
              icon: TablerRegular.circle_x,
              words: loc.pullRequestWatchNeedCiFailing,
              detail: loc.pullRequestWatchNeedCiFailingDetail,
            ),
            PullRequestWatchNeed.conflict => (
              icon: TablerRegular.git_merge,
              words: loc.pullRequestWatchNeedConflict,
              detail: loc.pullRequestWatchNeedConflictDetail,
            ),
            PullRequestWatchNeed.newReviewComments => (
              icon: TablerRegular.message_circle,
              words: loc.pullRequestWatchNeedNewReviewComments,
              detail: loc.pullRequestWatchNeedNewReviewCommentsDetail,
            ),
            PullRequestWatchNeed.readyWithoutAutoMerge || PullRequestWatchNeed.unknown => null,
          },
      ],
      PullRequestWatchStatusWaiting() ||
      PullRequestWatchStatusReady() ||
      PullRequestWatchStatusMerged() ||
      PullRequestWatchStatusUnknown() => const <({IconData icon, String words, String detail})>[],
    };
    final words = switch (stage) {
      PullRequestWatchStage.waiting when watch.autoMerge => loc.pullRequestWatchStageWaitingThenMerges,
      _ => look.words,
    };
    final duration = context.isReducedMotion ? Duration.zero : pregoAnimatedListItemDuration;
    final tertiary = colors.textTertiary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(PregoSpacing.xl, 0, PregoSpacing.xl, PregoSpacing.lg),
          // A status change grows or folds the reasons rather than snapping.
          child: AnimatedSize(
            duration: duration,
            curve: Curves.easeOut,
            alignment: AlignmentDirectional.topStart,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: PregoSpacing.md,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: PregoSpacing.sm,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(look.glyph, size: 20, color: look.color),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: words,
                              style: text.textMd.medium.copyWith(color: look.color),
                            ),
                            TextSpan(text: " · ${watch.repository}#${watch.number}"),
                          ],
                        ),
                        style: text.textMd.regular.copyWith(color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
                for (final reason in reasons)
                  Row(
                    key: ValueKey(reason.words),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: PregoSpacing.md,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(reason.icon, size: 18, color: colors.textSecondary),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(reason.words, style: text.textSm.medium.copyWith(color: colors.textPrimary)),
                            Text(reason.detail, style: text.textSm.regular.copyWith(color: colors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        PregoGroupedRows(
          children: [
            PregoGroupedRow(
              key: const Key("pull-request-watch-open-on-github"),
              icon: TablerRegular.brand_github,
              title: Text(loc.pullRequestWatchOpenOnGitHub),
              trailing: Icon(TablerRegular.external_link, size: 18, color: tertiary),
              onTap: onOpenOnGitHub,
            ),
            if (onOpenSession case final open?)
              PregoGroupedRow(
                key: const Key("pull-request-watch-go-to-session"),
                icon: TablerRegular.message_circle,
                title: Text(loc.pullRequestWatchGoToSession),
                subtitle: Text(item.sessionTitle ?? loc.sessionListUntitled),
                trailing: Icon(TablerRegular.chevron_right, size: 18, color: tertiary),
                onTap: open,
              ),
            // A merged pull request has nothing left to merge.
            if (stage != PullRequestWatchStage.mergedToday)
              PregoGroupedRow(
                key: const Key("pull-request-watch-auto-merge"),
                icon: TablerRegular.arrows_join,
                title: Text(loc.pullRequestWatchAutoMergeSwitch),
                subtitle: Text(loc.pullRequestWatchAutoMergeDescription),
                trailing: PregoSwitch(value: watch.autoMerge, onChanged: onSetAutoMerge),
                onTap: () => onSetAutoMerge(!watch.autoMerge),
              ),
          ],
        ),
        const SizedBox(height: PregoSpacing.lg),
        PregoGroupedRows(
          children: [
            PregoGroupedRow(
              key: const Key("pull-request-watch-stop"),
              leading: Icon(TablerRegular.eye_off, size: 20, color: colors.textErrorPrimary),
              title: Text(loc.pullRequestWatchStop, style: TextStyle(color: colors.textErrorPrimary)),
              onTap: onStop,
            ),
          ],
        ),
        const SizedBox(height: PregoSpacing.md),
      ],
    );
  }
}
