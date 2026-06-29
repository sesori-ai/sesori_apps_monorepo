import "package:flutter/material.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/routing/app_router.dart";
import "../../../core/routing/current_project_name.dart";
import "../../../l10n/app_localizations.dart";

/// A single background task as a glass row inside the tasks card. Shows the
/// session's status icon, title + status text, and a disclosure chevron that
/// opens the (read-only) session detail.
class BackgroundTaskRow extends StatelessWidget {
  final String? projectId;
  final Session session;
  final SessionStatus? status;
  final bool isLast;

  const BackgroundTaskRow({
    super.key,
    required this.projectId,
    required this.session,
    this.status,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final title = session.title ?? loc.sessionDetailSubtaskUnnamed;

    return GlassListTile(
      isLast: isLast,
      onTap: () => context.pushRoute(
        AppRoute.sessionDetail(
          projectId: projectId ?? session.projectID,
          projectName: currentProjectName(context),
          sessionId: session.id,
          readOnly: true,
          sessionTitle: session.title,
        ),
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

    if (diff.inMinutes < 1) return "${loc.backgroundTaskStatusIdle} · ${loc.timestampJustNow}";
    if (diff.inHours < 1) return "${loc.backgroundTaskStatusIdle} · ${loc.timestampMinutesAgo(diff.inMinutes)}";
    if (diff.inDays < 1) return "${loc.backgroundTaskStatusIdle} · ${loc.timestampHoursAgo(diff.inHours)}";
    return "${loc.backgroundTaskStatusIdle} · ${loc.timestampDaysAgo(diff.inDays)}";
  }
}
