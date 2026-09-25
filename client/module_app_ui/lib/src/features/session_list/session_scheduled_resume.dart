import "package:intl/intl.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../l10n/app_localizations.dart";
import "../session_detail/widgets/session_auto_continuation_notice.dart";

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
String sessionScheduledResumeDescription({required AppLocalizations loc, required int continueAt}) =>
    loc.sessionListResumesAtDescription(sessionAutoContinuationLocalTime(loc: loc, milliseconds: continueAt));

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
    final at = DateTime.fromMillisecondsSinceEpoch(continueAt).toLocal();
    final now = DateTime.now();
    final sameDay = at.year == now.year && at.month == now.month && at.day == now.day;
    final format = sameDay ? DateFormat.jm(loc.localeName) : DateFormat.MMMd(loc.localeName).add_jm();
    final time = format.format(at);
    return Semantics(
      label: sessionScheduledResumeDescription(loc: loc, continueAt: continueAt),
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
