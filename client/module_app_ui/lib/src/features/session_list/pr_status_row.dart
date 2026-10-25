import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../l10n/app_localizations.dart";

// GitHub's merged purple: Prego has no status token that means "merged".
const _kPrMergedPurple = Color(0xFFA371F7);

/// The slot the state glyph sits in; wider than the glyph, which spaces it from
/// the number.
const double _iconSlotWidth = 20;
const double _stateIconSize = 14;

/// A session row's pull request: a state glyph, the number, and for an open
/// pull request its conflict, review and check marks.
///
/// The state needs no word: each state has its own glyph and colour, as on
/// GitHub, and assistive technology hears it from the glyph's label.
class const PrStatusRow({super.key, required final PullRequestInfo pr}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final colors = context.prego.colors;
    final state = _stateMark(colors: colors, loc: loc, state: pr.state);

    // Squeezed by a narrow pane, the fixed indicators clip rather than overflow.
    return UnconstrainedBox(
      constrainedAxis: Axis.vertical,
      alignment: AlignmentDirectional.centerStart,
      clipBehavior: Clip.hardEdge,
      child: Row(
        // Hugs its content: the row sits inline among the session footer's other
        // details, so it must not claim the whole line.
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: state.label,
            // The glyph speaks for itself; the tooltip only helps a pointer.
            excludeFromSemantics: true,
            child: SizedBox(
              width: _iconSlotWidth,
              child: Center(
                child: Icon(state.icon, size: _stateIconSize, color: state.color, semanticLabel: state.label),
              ),
            ),
          ),
          Flexible(
            child: Text(
              loc.prLabel(pr.number),
              style: context.prego.textTheme.textXs.regular.copyWith(color: colors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Conflict, review and check marks only matter while it is open.
          if (pr.state == PrState.open)
            for (final indicator in [
              ?_conflictIndicator(colors: colors, loc: loc, status: pr.mergeableStatus),
              ?_reviewIndicator(colors: colors, loc: loc, decision: pr.reviewDecision),
              ?_checkIndicator(colors: colors, loc: loc, status: pr.checkStatus),
            ])
              Padding(
                padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xs),
                child: Tooltip(
                  message: indicator.tooltip,
                  child: Icon(indicator.icon, size: PregoIconSize.sm, color: indicator.color),
                ),
              ),
        ],
      ),
    );
  }
}

/// GitHub's glyph and colour for each state, and the words that say it.
({IconData icon, Color color, String label}) _stateMark({
  required PregoColors colors,
  required AppLocalizations loc,
  required PrState state,
}) => switch (state) {
  PrState.open => (icon: TablerRegular.git_pull_request, color: colors.fgSuccessPrimary, label: loc.prStateOpen),
  PrState.merged => (icon: TablerRegular.git_merge, color: _kPrMergedPurple, label: loc.prStateMerged),
  PrState.closed => (
    icon: TablerRegular.git_pull_request_closed,
    color: colors.fgErrorPrimary,
    label: loc.prStateClosed,
  ),
  PrState.unknown => (icon: TablerRegular.git_pull_request, color: colors.textTertiary, label: loc.prStateUnknown),
};

/// A red warning while the open pull request conflicts with its base.
({IconData icon, Color color, String tooltip})? _conflictIndicator({
  required PregoColors colors,
  required AppLocalizations loc,
  required PrMergeableStatus status,
}) => switch (status) {
  PrMergeableStatus.conflicting => (
    icon: TablerRegular.alert_triangle,
    color: colors.fgErrorPrimary,
    tooltip: loc.prConflicting,
  ),
  PrMergeableStatus.mergeable || PrMergeableStatus.unknown => null,
};

/// Returns icon, color, and tooltip for the review decision, or null to hide it.
({IconData icon, Color color, String tooltip})? _reviewIndicator({
  required PregoColors colors,
  required AppLocalizations loc,
  required PrReviewDecision decision,
}) => switch (decision) {
  PrReviewDecision.approved => (
    icon: TablerRegular.circle_check,
    color: colors.fgSuccessPrimary,
    tooltip: loc.prReviewApproved,
  ),
  PrReviewDecision.changesRequested => (
    icon: TablerRegular.circle_x,
    color: colors.fgErrorPrimary,
    tooltip: loc.prReviewChangesRequested,
  ),
  PrReviewDecision.reviewRequired => (
    icon: TablerRegular.dots_circle_horizontal,
    color: colors.borderPrimary,
    tooltip: loc.prReviewRequired,
  ),
  PrReviewDecision.unknown => null,
};

/// Returns icon, color, and tooltip for the check status, or null to hide it.
({IconData icon, Color color, String tooltip})? _checkIndicator({
  required PregoColors colors,
  required AppLocalizations loc,
  required PrCheckStatus status,
}) => switch (status) {
  PrCheckStatus.success => (
    icon: TablerRegular.circle_check,
    color: colors.fgSuccessPrimary,
    tooltip: loc.prChecksSuccess,
  ),
  PrCheckStatus.failure => (
    icon: TablerRegular.alert_circle,
    color: colors.fgErrorPrimary,
    tooltip: loc.prChecksFailing,
  ),
  PrCheckStatus.pending => (icon: TablerRegular.clock, color: colors.fgWarningPrimary, tooltip: loc.prChecksPending),
  PrCheckStatus.none => null,
  PrCheckStatus.unknown => null,
};
