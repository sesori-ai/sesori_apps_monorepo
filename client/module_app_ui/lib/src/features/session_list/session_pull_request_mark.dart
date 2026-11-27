import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../widgets/pull_request_watch_look.dart";

/// A session row's mark for the pull requests its agent watches: one soft
/// pill holding the [lead]'s number and how many [others] there are. It is
/// tinted green while the lead waits for the user to merge it, and grey
/// otherwise.
class const SessionPullRequestMark({
  super.key,
  required final SessionPullRequestWatch lead,
  required final int others,

  /// The meta line's text style, which the pill shrinks a step from.
  required final TextStyle style,
}) extends StatelessWidget {
  static const double _glyphSize = 11;
  static const double _radius = 6;

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    final stage = PullRequestWatchStage.of(status: lead.status);
    final look = pullRequestWatchLook(context: context, stage: stage);
    final toMerge = stage == PullRequestWatchStage.toMerge;
    final foreground = toMerge ? colors.textSuccessPrimary : colors.textSecondary;
    final background = toMerge ? colors.textSuccessPrimary.withValues(alpha: 0.16) : colors.bgTertiary;
    return Semantics(
      label: context.loc.sessionListWatchingPullRequests(others, "${lead.number}", look.words),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(_radius)),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(5, 1, 6, 1),
          // One paragraph, so the glyph sits in the text's own line box.
          child: Text.rich(
            TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 3),
                    child: Icon(
                      toMerge ? TablerRegular.git_merge : TablerRegular.git_pull_request,
                      size: _glyphSize,
                      color: foreground,
                    ),
                  ),
                ),
                TextSpan(
                  text: "#${lead.number}",
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (others > 0) TextSpan(text: " +$others"),
              ],
            ),
            style: style.copyWith(color: foreground, fontSize: (style.fontSize ?? 13) - 1),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
          ),
        ),
      ),
    );
  }
}
