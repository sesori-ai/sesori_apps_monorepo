import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../l10n/app_localizations.dart";
import "session_row_metrics.dart";

// GitHub's merged purple: Prego has no status token that means "merged".
const _kPrMergedPurple = Color(0xFFA371F7);

/// Compact row showing PR number, state label, and review/check status dots.
///
/// Used inside [_SessionTile] to surface pull-request metadata directly in the
/// session list without navigating to the detail screen.
class const PrStatusRow({super.key, required final PullRequestInfo pr}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final stateColor = _stateColor(colors: context.prego.colors, state: pr.state);
    final mergeIcon = _mergeIcon(status: pr.mergeableStatus);
    final mergeColor = _mergeColor(colors: context.prego.colors, status: pr.mergeableStatus) ?? stateColor;

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
            message: _mergeTooltip(loc: loc, status: pr.mergeableStatus),
            // The same slot the footer's other detail marks sit in, so the two
            // details keep one rhythm across the line.
            child: SizedBox(
              width: kSessionRowIconSlotWidth,
              child: Center(
                child: Icon(mergeIcon, size: kSessionRowDetailIconSize, color: mergeColor),
              ),
            ),
          ),
          Flexible(
            child: Text(
              loc.prLabel(pr.number),
              style: context.prego.textTheme.textXs.regular.copyWith(color: context.prego.colors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _stateText(loc: loc, state: pr.state),
              style: context.prego.textTheme.textXs.regular.copyWith(color: stateColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Review/check indicators are only relevant for open PRs.
          if (pr.state == PrState.open) ...[
            if (_reviewIndicator(colors: context.prego.colors, loc: loc, decision: pr.reviewDecision)
                case (:final icon, :final color, :final tooltip)?) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: tooltip,
                child: Icon(icon, size: PregoIconSize.sm, color: color),
              ),
            ],
            if (_checkIndicator(colors: context.prego.colors, loc: loc, status: pr.checkStatus)
                case (:final icon, :final color, :final tooltip)?) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: tooltip,
                child: Icon(icon, size: PregoIconSize.sm, color: color),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// State helpers
// ---------------------------------------------------------------------------

Color _stateColor({required PregoColors colors, required PrState state}) => switch (state) {
  PrState.open => colors.fgSuccessPrimary,
  PrState.merged => _kPrMergedPurple,
  PrState.closed => colors.borderPrimary,
  PrState.unknown => colors.borderPrimary,
};

String _stateText({required AppLocalizations loc, required PrState state}) => switch (state) {
  PrState.open => loc.prStateOpen,
  PrState.merged => loc.prStateMerged,
  PrState.closed => loc.prStateClosed,
  PrState.unknown => "",
};

// ---------------------------------------------------------------------------
// Mergeable status helpers
// ---------------------------------------------------------------------------

/// Returns a color for the merge icon, or null to fall back to the state color.
Color? _mergeColor({required PregoColors colors, required PrMergeableStatus status}) => switch (status) {
  PrMergeableStatus.mergeable => colors.fgSuccessPrimary,
  PrMergeableStatus.conflicting => colors.fgErrorPrimary,
  PrMergeableStatus.unknown => null,
};

IconData _mergeIcon({required PrMergeableStatus status}) => switch (status) {
  PrMergeableStatus.mergeable => TablerRegular.git_merge,
  PrMergeableStatus.conflicting => TablerRegular.alert_triangle,
  PrMergeableStatus.unknown => TablerRegular.git_merge,
};

String _mergeTooltip({required AppLocalizations loc, required PrMergeableStatus status}) => switch (status) {
  PrMergeableStatus.mergeable => loc.prMergeable,
  PrMergeableStatus.conflicting => loc.prConflicting,
  PrMergeableStatus.unknown => "",
};

// ---------------------------------------------------------------------------
// Review decision indicator
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Check status indicator
// ---------------------------------------------------------------------------

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
