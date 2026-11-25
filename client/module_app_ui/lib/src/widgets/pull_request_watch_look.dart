import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";

/// How a watched pull request's status reads: the colour of its number and
/// glyph, and its word for a screen reader or a menu row. Red asks for the
/// user, green is ready, the accent is still in progress, and merged or
/// unknown stay quiet.
({Color color, String words}) pullRequestWatchLook({
  required BuildContext context,
  required PullRequestWatchStatus status,
}) {
  final colors = context.prego.colors;
  final loc = context.loc;
  return switch (status) {
    PullRequestWatchStatusNeedsYou() => (color: colors.textErrorPrimary, words: loc.pullRequestWatchStatusNeedsYou),
    PullRequestWatchStatusReady() => (color: colors.textSuccessPrimary, words: loc.pullRequestWatchStatusReady),
    PullRequestWatchStatusWaiting() => (color: colors.textBrandSecondary, words: loc.pullRequestWatchStatusWaiting),
    PullRequestWatchStatusMerged() => (color: colors.textSecondary, words: loc.pullRequestWatchStatusMerged),
    PullRequestWatchStatusUnknown() => (color: colors.textSecondary, words: loc.pullRequestWatchStatusUnknown),
  };
}
