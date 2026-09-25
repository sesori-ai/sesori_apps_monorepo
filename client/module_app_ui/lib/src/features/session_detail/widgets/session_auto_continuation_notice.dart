import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";
import "../../../utils/auto_continuation_time.dart";

/// Whether the session needs the auto-continuation card above the composer:
/// a quota reset to offer or explain, a continuation waiting to send, or an
/// attempt the user should know about. An enabled preference with nothing due
/// shows only the quiet model-row chip instead.
bool sessionAutoContinuationNoticeVisible({required SessionAutoContinuationView? view}) {
  if (view == null) return false;
  return switch (view.status) {
    // Disabled, the card offers the reset; enabled, it counts down or explains
    // why nothing can be scheduled.
    SessionAutoContinuationResetKnown() || SessionAutoContinuationResetUnknown() => true,
    SessionAutoContinuationPaused() ||
    SessionAutoContinuationAttemptUnconfirmed() ||
    SessionAutoContinuationSubmissionFailed() ||
    SessionAutoContinuationUnknown() => view.enabled,
    // Nothing is due: no interruption yet, or the continuation was already
    // sent and shows in the transcript.
    SessionAutoContinuationIdle() || SessionAutoContinuationSubmitted() => false,
  };
}

/// Presents the bridge's state; it never calculates a deadline or runs a timer.
class const SessionAutoContinuationNotice({
  super.key,
  required final SessionAutoContinuationView? view,
  required final bool updating,
  required final bool canInteract,
  required final ValueChanged<bool> onEnabledChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final current = view;
    if (current == null || !sessionAutoContinuationNoticeVisible(view: current)) return const SizedBox.shrink();
    final status = current.status;
    final loc = context.loc;
    final prego = context.prego;
    final available = current.availability == AutoContinuationAvailability.conditional && canInteract;
    final message = available
        ? _statusText(loc: loc, status: status, enabled: current.enabled)
        : loc.sessionAutoContinuationUnavailable;
    final canEnable = !current.enabled && available && status is SessionAutoContinuationResetKnown;
    final action = current.enabled ? loc.sessionAutoContinuationDisable : loc.sessionAutoContinuationEnable;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(PregoSpacing.xl, 0, PregoSpacing.xl, PregoSpacing.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: prego.colors.bgSecondary,
            borderRadius: BorderRadius.circular(PregoRadius.x2l),
          ),
          child: Padding(
            padding: const EdgeInsets.all(PregoSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: PregoSpacing.md,
                  runSpacing: PregoSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(TablerRegular.clock, size: PregoIconSize.sm, color: prego.colors.textSecondary),
                    Text(
                      current.enabled ? loc.sessionAutoContinuationOn : loc.sessionAutoContinuationQuotaReached,
                      style: prego.textTheme.textSm.medium,
                    ),
                    if (current.enabled)
                      PregoButtonsSolid(
                        key: const Key("session-auto-continuation-disable"),
                        label: action,
                        hierarchy: PregoButtonsSolidHierarchy.link,
                        size: PregoButtonsSolidSize.sm,
                        onPressed: updating ? null : () => onEnabledChanged(false),
                      ),
                  ],
                ),
                if (message != null) ...[
                  const SizedBox(height: PregoSpacing.xs),
                  Text(message, style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary)),
                ],
                if (canEnable) ...[
                  const SizedBox(height: PregoSpacing.md),
                  PregoButtonsSolid(
                    key: const Key("session-auto-continuation-enable"),
                    label: action,
                    hierarchy: PregoButtonsSolidHierarchy.secondary,
                    size: PregoButtonsSolidSize.sm,
                    onPressed: updating ? null : () => onEnabledChanged(true),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _statusText({
    required AppLocalizations loc,
    required SessionAutoContinuationStatus status,
    required bool enabled,
  }) => switch (status) {
    // The card is hidden for these; the model-row chip explains them.
    SessionAutoContinuationIdle() || SessionAutoContinuationSubmitted() => null,
    SessionAutoContinuationResetKnown(:final continueAt) =>
      enabled
          ? loc.sessionAutoContinuationScheduled(sessionAutoContinuationLocalTime(loc: loc, milliseconds: continueAt))
          : loc.sessionAutoContinuationOffer(sessionAutoContinuationLocalTime(loc: loc, milliseconds: continueAt)),
    SessionAutoContinuationResetUnknown() => loc.sessionAutoContinuationResetUnknown,
    SessionAutoContinuationPaused(:final reason) => switch (reason) {
      AutoContinuationPauseReason.busy ||
      AutoContinuationPauseReason.retrying ||
      AutoContinuationPauseReason.queued => loc.sessionAutoContinuationPausedWork,
      AutoContinuationPauseReason.awaitingInput => loc.sessionAutoContinuationPausedInput,
      AutoContinuationPauseReason.unavailable => loc.sessionAutoContinuationPausedUnavailable,
      AutoContinuationPauseReason.historyUnavailable ||
      AutoContinuationPauseReason.unknown => loc.sessionAutoContinuationPausedUnknown,
    },
    SessionAutoContinuationAttemptUnconfirmed() => loc.sessionAutoContinuationUnconfirmed,
    SessionAutoContinuationSubmissionFailed() => loc.sessionAutoContinuationFailed,
    SessionAutoContinuationUnknown() => loc.sessionAutoContinuationStatusUnknown,
  };
}
