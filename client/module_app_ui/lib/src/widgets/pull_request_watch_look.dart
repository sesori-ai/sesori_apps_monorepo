import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";

/// How a watched pull request's stage looks: its glyph, its colour, and its
/// word. Green with the merge glyph is To merge, the only stage that needs the
/// user; the accent says the agent is on it; Merges automatically is a quiet
/// green; waiting and merged stay grey. Nothing is red.
({IconData glyph, Color color, String words}) pullRequestWatchLook({
  required BuildContext context,
  required PullRequestWatchStage stage,
}) {
  final colors = context.prego.colors;
  final loc = context.loc;
  return switch (stage) {
    PullRequestWatchStage.toMerge => (
      glyph: TablerRegular.git_merge,
      color: colors.textSuccessPrimary,
      words: loc.pullRequestWatchStageToMerge,
    ),
    PullRequestWatchStage.agentOnIt => (
      glyph: TablerRegular.sparkles,
      color: colors.textBrandSecondary,
      words: loc.pullRequestWatchStageAgentOnIt,
    ),
    PullRequestWatchStage.waiting => (
      glyph: TablerRegular.clock,
      color: colors.textSecondary,
      words: loc.pullRequestWatchStageWaiting,
    ),
    PullRequestWatchStage.mergesAutomatically => (
      glyph: TablerRegular.arrows_join,
      color: colors.textSuccessPrimary,
      words: loc.pullRequestWatchStageMergesAutomatically,
    ),
    PullRequestWatchStage.mergedToday => (
      glyph: TablerRegular.git_merge,
      color: colors.textTertiary,
      words: loc.pullRequestWatchStageMerged,
    ),
  };
}

/// The reasons the agent is on a pull request in [status], in words: the
/// first starts with a capital, the rest follow it in a comma list. Null when
/// the agent has nothing to do.
String? pullRequestWatchAgentReasons({required BuildContext context, required PullRequestWatchStatus status}) {
  if (status is! PullRequestWatchStatusNeedsYou) return null;
  final loc = context.loc;
  final words = [
    for (final reason in status.reasons)
      ?switch (reason) {
        PullRequestWatchNeed.ciFailing => (
          first: loc.pullRequestWatchNeedCiFailing,
          later: loc.pullRequestWatchNeedCiFailingInList,
        ),
        PullRequestWatchNeed.conflict => (
          first: loc.pullRequestWatchNeedConflict,
          later: loc.pullRequestWatchNeedConflictInList,
        ),
        PullRequestWatchNeed.newReviewComments => (
          first: loc.pullRequestWatchNeedNewReviewComments,
          later: loc.pullRequestWatchNeedNewReviewCommentsInList,
        ),
        PullRequestWatchNeed.readyWithoutAutoMerge || PullRequestWatchNeed.unknown => null,
      },
  ];
  if (words.isEmpty) return null;
  return [words.first.first, for (final word in words.skip(1)) word.later].join(", ");
}
