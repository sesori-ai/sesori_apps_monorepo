import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/routing/app_router.dart";
import "../../../core/routing/current_project_name.dart";
import "../../../l10n/app_localizations.dart";

class BackgroundTaskRow extends StatelessWidget {
  final String? projectId;
  final Session session;
  final SessionStatus? status;

  const BackgroundTaskRow({
    super.key,
    required this.projectId,
    required this.session,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final title = session.title ?? loc.sessionDetailSubtaskUnnamed;

    return InkWell(
      onTap: () => context.pushRoute(
        AppRoute.sessionDetail(
          projectId: projectId ?? session.projectID,
          projectName: currentProjectName(context),
          sessionId: session.id,
          readOnly: true,
          sessionTitle: session.title,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _statusIcon(status: status, prego: prego),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: prego.textTheme.textSm.regular,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  _statusTextWidget(
                    loc: loc,
                    status: status,
                    prego: prego,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: prego.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon({required SessionStatus? status, required PregoDesignSystem prego}) => switch (status) {
    SessionStatusBusy() || SessionStatusRetry() => SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: prego.colors.bgBrandSolid,
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

    if (diff.inMinutes < 1) return "${loc.backgroundTaskStatusIdle} \u00b7 ${loc.timestampJustNow}";
    if (diff.inHours < 1) return "${loc.backgroundTaskStatusIdle} \u00b7 ${loc.timestampMinutesAgo(diff.inMinutes)}";
    if (diff.inDays < 1) return "${loc.backgroundTaskStatusIdle} \u00b7 ${loc.timestampHoursAgo(diff.inHours)}";
    return "${loc.backgroundTaskStatusIdle} \u00b7 ${loc.timestampDaysAgo(diff.inDays)}";
  }
}
