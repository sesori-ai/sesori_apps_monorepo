import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";
import "../session_detail_presentation_scope.dart";

/// A single background task as a row inside the tasks card. Shows the
/// session's status icon, title + status text, and a disclosure chevron that
/// opens the (read-only) session detail.
class const BackgroundTaskRow({
  super.key,
  required final String? projectId,
  required final Session session,
  final SessionStatus? status,
  final bool isLast = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final title = session.title ?? loc.sessionDetailSubtaskUnnamed;

    return PregoListTile(
      isLast: isLast,
      onTap: () => SessionDetailPresentationScope.read(context).openSession(
        projectId: projectId ?? session.projectID,
        sessionId: session.id,
        readOnly: true,
        sessionTitle: session.title,
      ),
      leading: _statusIcon(status: status, prego: prego),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      titleStyle: prego.textTheme.textSm.regular,
      subtitle: _statusTextWidget(loc: loc, status: status, prego: prego),
      subtitleStyle: prego.textTheme.textXs.regular.copyWith(
        color: prego.colors.textSecondary,
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: prego.colors.textSecondary,
      ),
    );
  }

  Widget _statusIcon({required SessionStatus? status, required PregoDesignSystem prego}) => switch (status) {
    // The leading slot is a tight 32px wide but leaves its height free. Center
    // re-loosens those constraints around a fixed 16px square.
    SessionStatusBusy() || SessionStatusRetry() => const Center(
      heightFactor: 1,
      child: SizedBox.square(
        dimension: 16,
        child: PregoActivityIndicator(color: null),
      ),
    ),
    SessionStatusIdle() || null => Icon(
      Icons.check_circle,
      size: 16,
      color: prego.colors.bgBrandSolid,
    ),
  };

  Widget _statusTextWidget({
    required AppLocalizations loc,
    required SessionStatus? status,
    required PregoDesignSystem prego,
  }) => switch (status) {
    SessionStatusBusy() => Text(
      loc.backgroundTaskStatusBusy,
      style: prego.textTheme.textXs.regular.copyWith(
        color: prego.colors.textSecondary,
      ),
    ),
    SessionStatusRetry(:final message) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: loc.backgroundTaskStatusRetry,
            style: prego.textTheme.textXs.regular.copyWith(
              color: prego.colors.textSecondary,
            ),
          ),
          TextSpan(
            text: ' ($message)',
            style: prego.textTheme.textXs.regular.copyWith(
              color: prego.colors.fgErrorPrimary,
            ),
          ),
        ],
      ),
    ),
    SessionStatusIdle() || null => Text(
      _completedLabel(loc),
      style: prego.textTheme.textXs.regular.copyWith(
        color: prego.colors.textSecondary,
      ),
    ),
  };

  String _completedLabel(AppLocalizations loc) {
    final updatedMs = session.time?.updated;
    if (updatedMs == null) return loc.backgroundTaskStatusIdle;

    final diff = DateTime.now().toUtc().difference(
      DateTime.fromMillisecondsSinceEpoch(updatedMs, isUtc: true),
    );

    if (diff.inMinutes < 1) return "${loc.backgroundTaskStatusIdle} · ${loc.timestampJustNow}";
    if (diff.inHours < 1) return "${loc.backgroundTaskStatusIdle} · ${loc.timestampMinutesAgo(diff.inMinutes)}";
    if (diff.inDays < 1) return "${loc.backgroundTaskStatusIdle} · ${loc.timestampHoursAgo(diff.inHours)}";
    return "${loc.backgroundTaskStatusIdle} · ${loc.timestampDaysAgo(diff.inDays)}";
  }
}
