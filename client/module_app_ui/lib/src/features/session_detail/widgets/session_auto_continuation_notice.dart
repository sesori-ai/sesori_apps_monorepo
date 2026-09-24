import "package:intl/intl.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";

/// Presents the bridge's state; it never calculates a deadline or runs a timer.
class const SessionAutoContinuationNotice({
  super.key,
  required final SessionAutoContinuationView? view,
  required final bool updating,
  required final ValueChanged<bool> onEnabledChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final current = view;
    if (current == null) return const SizedBox.shrink();
    final status = current.status;
    if (!current.enabled &&
        status is! SessionAutoContinuationResetKnown &&
        status is! SessionAutoContinuationResetUnknown) {
      return const SizedBox.shrink();
    }
    final loc = context.loc;
    final prego = context.prego;
    final available = current.availability == AutoContinuationAvailability.conditional;
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
    SessionAutoContinuationIdle() => null,
    SessionAutoContinuationResetKnown(:final continueAt) =>
      enabled
          ? loc.sessionAutoContinuationScheduled(_localTime(loc: loc, milliseconds: continueAt))
          : loc.sessionAutoContinuationOffer(_localTime(loc: loc, milliseconds: continueAt)),
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
    SessionAutoContinuationSubmitted(:final acceptedAt) => loc.sessionAutoContinuationSubmitted(
      _localTime(loc: loc, milliseconds: acceptedAt),
    ),
    SessionAutoContinuationSubmissionFailed() => loc.sessionAutoContinuationFailed,
    SessionAutoContinuationUnknown() => loc.sessionAutoContinuationStatusUnknown,
  };

  String _localTime({required AppLocalizations loc, required int milliseconds}) =>
      DateFormat.yMMMd(loc.localeName).add_jm().format(DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal());
}
