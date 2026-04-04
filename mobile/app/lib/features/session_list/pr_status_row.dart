import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/extensions/build_context_x.dart";
import "../../l10n/app_localizations.dart";

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

    return Row(
      children: [
        Icon(Icons.merge_type, size: 14, color: stateColor),
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
  PrState.open => const Color(0xFF3FB950),
  PrState.merged => const Color(0xFFA371F7),
  PrState.closed => scheme.outline,
  PrState.unknown => scheme.outline,
};

String _stateText({required AppLocalizations loc, required PrState state}) => switch (state) {
  PrState.open => loc.prStateOpen,
  PrState.merged => loc.prStateMerged,
  PrState.closed => loc.prStateClosed,
  PrState.unknown => loc.prStateClosed,
};

// ---------------------------------------------------------------------------
// Review decision helpers
// ---------------------------------------------------------------------------

/// Returns a color when the review decision should display a dot, or null to hide it.
Color? _reviewColor({required ColorScheme scheme, required PrReviewDecision decision}) => switch (decision) {
  PrReviewDecision.approved => const Color(0xFF3FB950),
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
  PrCheckStatus.success => const Color(0xFF3FB950),
  PrCheckStatus.failure => scheme.error,
  PrCheckStatus.pending => const Color(0xFFD29922),
  PrCheckStatus.unknown => null,
};

IconData _checkIcon({required PrCheckStatus status}) => switch (status) {
  PrCheckStatus.success => Icons.check_circle_outline,
  PrCheckStatus.failure => Icons.error_outline,
  PrCheckStatus.pending => Icons.schedule,
  PrCheckStatus.unknown => Icons.circle,
};

String _checkTooltip({required AppLocalizations loc, required PrCheckStatus status}) => switch (status) {
  PrCheckStatus.success => loc.prChecksSuccess,
  PrCheckStatus.failure => loc.prChecksFailing,
  PrCheckStatus.pending => loc.prChecksPending,
  PrCheckStatus.unknown => "",
};
