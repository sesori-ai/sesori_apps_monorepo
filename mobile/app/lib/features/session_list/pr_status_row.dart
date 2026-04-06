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
        if (_reviewColor(scheme: theme.colorScheme, decision: pr.reviewDecision) case final color?) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: _reviewTooltip(loc: loc, decision: pr.reviewDecision),
            child: Icon(_reviewIcon(decision: pr.reviewDecision), size: 12, color: color),
          ),
        ],
        if (_checkColor(scheme: theme.colorScheme, status: pr.checkStatus) case final color?) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: _checkTooltip(loc: loc, status: pr.checkStatus),
            child: Icon(_checkIcon(status: pr.checkStatus), size: 12, color: color),
          ),
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
// Review decision helpers
// ---------------------------------------------------------------------------

/// Returns a color when the review decision should display a dot, or null to hide it.
Color? _reviewColor({required ColorScheme scheme, required PrReviewDecision decision}) => switch (decision) {
  PrReviewDecision.approved => _kPrGreen,
  PrReviewDecision.changesRequested => scheme.error,
  PrReviewDecision.reviewRequired => scheme.outline,
  PrReviewDecision.unknown => null,
};

IconData _reviewIcon({required PrReviewDecision decision}) => switch (decision) {
  PrReviewDecision.approved => Icons.check_circle_outline,
  PrReviewDecision.changesRequested => Icons.cancel_outlined,
  PrReviewDecision.reviewRequired => Icons.pending_outlined,
  PrReviewDecision.unknown => Icons.circle,
};

String _reviewTooltip({required AppLocalizations loc, required PrReviewDecision decision}) => switch (decision) {
  PrReviewDecision.approved => loc.prReviewApproved,
  PrReviewDecision.changesRequested => loc.prReviewChangesRequested,
  PrReviewDecision.reviewRequired => loc.prReviewRequired,
  PrReviewDecision.unknown => "",
};

// ---------------------------------------------------------------------------
// Check status helpers
// ---------------------------------------------------------------------------

/// Returns a color when the check status should display a dot, or null to hide it.
Color? _checkColor({required ColorScheme scheme, required PrCheckStatus status}) => switch (status) {
  PrCheckStatus.success => _kPrGreen,
  PrCheckStatus.failure => scheme.error,
  PrCheckStatus.pending => _kPrAmber,
  PrCheckStatus.none => null,
  PrCheckStatus.unknown => null,
};

IconData _checkIcon({required PrCheckStatus status}) => switch (status) {
  PrCheckStatus.success => Icons.check_circle_outline,
  PrCheckStatus.failure => Icons.error_outline,
  PrCheckStatus.pending => Icons.schedule,
  PrCheckStatus.none => Icons.circle,
  PrCheckStatus.unknown => Icons.circle,
};

String _checkTooltip({required AppLocalizations loc, required PrCheckStatus status}) => switch (status) {
  PrCheckStatus.success => loc.prChecksSuccess,
  PrCheckStatus.failure => loc.prChecksFailing,
  PrCheckStatus.pending => loc.prChecksPending,
  PrCheckStatus.none => "",
  PrCheckStatus.unknown => "",
};
