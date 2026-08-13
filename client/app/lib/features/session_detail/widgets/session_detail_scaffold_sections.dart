import "package:flutter/material.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/extensions/remote_failure_x.dart";

/// A floating call-to-action pinned below the top bar when the session has a
/// pending question or permission. Rendered as a semantic-tinted liquid-glass
/// card (brand for questions, success for permissions) so it pops over the chat
/// while sharing the glass language of the background-tasks card and the
/// composer pills below.
class const SessionDetailPendingBanner({
  super.key,
  required final IconData icon,

  /// Semantic surface colour for the glass tint — applied with reduced alpha so
  /// the card stays frosted and the chat refracts through its edges.
  required final Color backgroundColor,
  required final Color foregroundColor,
  required final String label,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
      child: GlassContainer(
        useOwnLayer: true,
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.zero,
        shape: const LiquidRoundedSuperellipse(borderRadius: 20),
        settings: LiquidGlassSettings(glassColor: backgroundColor.withValues(alpha: 0.6)),
        child: GlassListTile(
          onTap: onTap,
          leading: Icon(icon, size: 20, color: foregroundColor),
          title: Text(label),
          titleStyle: prego.textTheme.textMd.bold.copyWith(color: foregroundColor),
          trailing: Icon(Icons.chevron_right, size: 20, color: foregroundColor),
        ),
      ),
    );
  }
}

/// Explains why an archived session shows no composer: archiving is permanent,
/// so the session is readable but can never be prompted or reopened again.
class const SessionDetailArchivedNotice({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
      child: GlassContainer(
        useOwnLayer: true,
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.zero,
        shape: const LiquidRoundedSuperellipse(borderRadius: 20),
        settings: LiquidGlassSettings(glassColor: prego.colors.bgSecondary.withValues(alpha: 0.6)),
        child: GlassListTile(
          leading: Icon(Icons.archive_outlined, size: 20, color: prego.colors.textSecondary),
          title: Text(context.loc.sessionDetailArchivedNotice),
          titleStyle: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
        ),
      ),
    );
  }
}

class const SessionDetailErrorView({
  super.key,
  required final RemoteFailureReason reason,
  required final VoidCallback onRetry,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.prego.colors.fgErrorPrimary),
            const SizedBox(height: 16),
            Text(loc.sessionDetailErrorTitle, style: context.prego.textTheme.textMd.bold),
            const SizedBox(height: 8),
            Text(
              reason.localizedMessage(loc),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(loc.sessionDetailRetry),
            ),
          ],
        ),
      ),
    );
  }
}
