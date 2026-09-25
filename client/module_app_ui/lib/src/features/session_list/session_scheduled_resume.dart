import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";

/// When the bridge will continue this session on its own, or null when no
/// continuation is scheduled. Paused, unknown-reset and failed states are left
/// to the session's own notice, which explains them; an older bridge sends no
/// view at all.
int? sessionScheduledResumeAt({required SessionAutoContinuationView? view}) {
  if (view == null || !view.enabled || view.availability != AutoContinuationAvailability.conditional) return null;
  return switch (view.status) {
    SessionAutoContinuationResetKnown(:final continueAt) => continueAt,
    SessionAutoContinuationIdle() ||
    SessionAutoContinuationResetUnknown() ||
    SessionAutoContinuationPaused() ||
    SessionAutoContinuationAttemptUnconfirmed() ||
    SessionAutoContinuationSubmitted() ||
    SessionAutoContinuationSubmissionFailed() ||
    SessionAutoContinuationUnknown() => null,
  };
}

/// What a session row says in full about its scheduled continuation.
String sessionScheduledResumeDescription({required BuildContext context, required int continueAt}) =>
    context.loc.sessionListResumesAtDescription(context.formatDateTime(ms: continueAt));

/// A session row's trailing mark in place of its last-activity time while a
/// continuation is scheduled: a clock and the local time it resumes, with the
/// date only when that is not today. A narrow row, like the desktop sidebar's,
/// drops the "Resumes" word and keeps the clock and time; its assistive label
/// and tooltip still say it in full.
class const SessionScheduledResume({
  super.key,
  required final int continueAt,
  required final bool labelled,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final color = prego.colors.textSecondary;
    // The device's time and date patterns, like every other list timestamp.
    final time = context.formatMessageTimestamp(continueAt);
    return Semantics(
      label: sessionScheduledResumeDescription(context: context, continueAt: continueAt),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: PregoSpacing.xs,
        children: [
          Icon(TablerRegular.clock, size: PregoIconSize.sm, color: color),
          Flexible(
            child: Text(
              labelled ? loc.sessionListResumes(time) : time,
              style: prego.textTheme.textXs.regular.copyWith(color: color),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
