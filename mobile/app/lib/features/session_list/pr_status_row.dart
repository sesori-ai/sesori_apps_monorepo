import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/extensions/build_context_x.dart";
import "../../l10n/app_localizations.dart";

// GitHub-inspired semantic status colors, chosen for light/dark contrast.
const _kPrGreen = Color(0xFF3FB950);
const _kPrPurple = Color(0xFFA371F7);
const _kPrAmber = Color(0xFFD29922);

/// Compact row showing PR number, state label, and review/check status dots.
///
/// Used inside [_SessionTile] to surface pull-request metadata directly in the
/// session list without navigating to the detail screen.
class PrStatusRow extends StatelessWidget {
  final PullRequestInfo pr;

  const PrStatusRow({super.key, required this.pr});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;
    final stateColor = _stateColor(scheme: theme.colorScheme, state: pr.state);
    final mergeIcon = _mergeIcon(status: pr.mergeableStatus);
    final mergeColor = _mergeColor(scheme: theme.colorScheme, status: pr.mergeableStatus) ?? stateColor;

    return Row(
      children: [
        Tooltip(
          message: _mergeTooltip(loc: loc, status: pr.mergeableStatus),
          child: Icon(mergeIcon, size: 14, color: mergeColor),
        ),
        const SizedBox(width: 4),
        Text(
          loc.prLabel(pr.number),
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 6),
        Text(
          _stateText(loc: loc, state: pr.state),
          style: theme.textTheme.bodySmall?.copyWith(color: stateColor),
        ),
        // Review/check indicators are only relevant for open PRs.
        if (pr.state == PrState.open) ...[
          if (_reviewIndicator(scheme: theme.colorScheme, loc: loc, decision: pr.reviewDecision)
              case (:final icon, :final color, :final tooltip)?) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: tooltip,
              child: Icon(icon, size: 12, color: color),
            ),
          ],
          if (_checkIndicator(scheme: theme.colorScheme, loc: loc, status: pr.checkStatus)
              case (:final icon, :final color, :final tooltip)?) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: tooltip,
              child: Icon(icon, size: 12, color: color),
            ),
          ],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// State helpers
// ---------------------------------------------------------------------------

Color _stateColor({required ColorScheme scheme, required PrState state}) => switch (state) {
  PrState.open => _kPrGreen,
  PrState.merged => _kPrPurple,
  PrState.closed => scheme.outline,
  PrState.unknown => scheme.outline,
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
Color? _mergeColor({required ColorScheme scheme, required PrMergeableStatus status}) => switch (status) {
  PrMergeableStatus.mergeable => _kPrGreen,
  PrMergeableStatus.conflicting => scheme.error,
  PrMergeableStatus.unknown => null,
};

IconData _mergeIcon({required PrMergeableStatus status}) => switch (status) {
  PrMergeableStatus.mergeable => Icons.merge_type,
  PrMergeableStatus.conflicting => Icons.warning_amber_rounded,
  PrMergeableStatus.unknown => Icons.merge_type,
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
  required ColorScheme scheme,
  required AppLocalizations loc,
  required PrReviewDecision decision,
}) => switch (decision) {
  PrReviewDecision.approved => (icon: Icons.check_circle_outline, color: _kPrGreen, tooltip: loc.prReviewApproved),
  PrReviewDecision.changesRequested => (
    icon: Icons.cancel_outlined,
    color: scheme.error,
    tooltip: loc.prReviewChangesRequested,
  ),
  PrReviewDecision.reviewRequired => (
    icon: Icons.pending_outlined,
    color: scheme.outline,
    tooltip: loc.prReviewRequired,
  ),
  PrReviewDecision.unknown => null,
};

// ---------------------------------------------------------------------------
// Check status indicator
// ---------------------------------------------------------------------------

/// Returns icon, color, and tooltip for the check status, or null to hide it.
({IconData icon, Color color, String tooltip})? _checkIndicator({
  required ColorScheme scheme,
  required AppLocalizations loc,
  required PrCheckStatus status,
}) => switch (status) {
  PrCheckStatus.success => (icon: Icons.check_circle_outline, color: _kPrGreen, tooltip: loc.prChecksSuccess),
  PrCheckStatus.failure => (icon: Icons.error_outline, color: scheme.error, tooltip: loc.prChecksFailing),
  PrCheckStatus.pending => (icon: Icons.schedule, color: _kPrAmber, tooltip: loc.prChecksPending),
  PrCheckStatus.none => null,
  PrCheckStatus.unknown => null,
};
