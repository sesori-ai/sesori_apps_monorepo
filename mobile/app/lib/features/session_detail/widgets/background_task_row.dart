import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";
import "adaptive_session_detail_navigation.dart";

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
    final zyra = context.zyra;
    final loc = context.loc;
    final title = session.title ?? loc.sessionDetailSubtaskUnnamed;

    return InkWell(
      onTap: () => openAdaptiveSessionDetail(
        context: context,
        projectId: projectId ?? session.projectID,
        sessionId: session.id,
        readOnly: true,
        sessionTitle: session.title,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _statusIcon(status: status, zyra: zyra),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: zyra.textTheme.textSm.regular,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  _statusTextWidget(
                    loc: loc,
                    status: status,
                    zyra: zyra,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: zyra.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon({required SessionStatus? status, required ZyraDesignSystem zyra}) => switch (status) {
    SessionStatusBusy() || SessionStatusRetry() => SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: zyra.colors.bgBrandSolid,
      ),
    ),
    SessionStatusIdle() => Icon(
      Icons.check_circle,
      size: 16,
      color: zyra.colors.bgBrandSolid,
    ),
    null => Icon(
      Icons.play_circle_outline,
      size: 16,
      color: zyra.colors.borderPrimary,
    ),
  };

  Widget _statusTextWidget({
    required AppLocalizations loc,
    required SessionStatus? status,
    required ZyraDesignSystem zyra,
  }) => switch (status) {
    SessionStatusBusy() => Text(
      loc.backgroundTaskStatusBusy,
      style: zyra.textTheme.textXs.regular.copyWith(
        color: zyra.colors.textSecondary,
      ),
    ),
    SessionStatusRetry(:final message) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: loc.backgroundTaskStatusRetry,
            style: zyra.textTheme.textXs.regular.copyWith(
              color: zyra.colors.textSecondary,
            ),
          ),
          TextSpan(
            text: ' ($message)',
            style: zyra.textTheme.textXs.regular.copyWith(
              color: zyra.colors.fgErrorPrimary,
            ),
          ),
        ],
      ),
    ),
    SessionStatusIdle() => Text(
      _completedLabel(loc),
      style: zyra.textTheme.textXs.regular.copyWith(
        color: zyra.colors.textSecondary,
      ),
    ),
    null => Text(
      _completedLabel(loc),
      style: zyra.textTheme.textXs.regular.copyWith(
        color: zyra.colors.textSecondary,
      ),
    ),
  };

  String _completedLabel(AppLocalizations loc) {
    final updatedMs = session.time?.updated;
    if (updatedMs == null) return loc.backgroundTaskStatusIdle;

    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(updatedMs),
    );

    if (diff.inMinutes < 1) return "${loc.backgroundTaskStatusIdle} \u00b7 just now";
    if (diff.inHours < 1) return "${loc.backgroundTaskStatusIdle} \u00b7 ${diff.inMinutes}m ago";
    if (diff.inDays < 1) return "${loc.backgroundTaskStatusIdle} \u00b7 ${diff.inHours}h ago";
    return "${loc.backgroundTaskStatusIdle} \u00b7 ${diff.inDays}d ago";
  }
}
