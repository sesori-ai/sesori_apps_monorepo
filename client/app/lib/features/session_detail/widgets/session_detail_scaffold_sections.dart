import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/extensions/remote_failure_x.dart";
import "queued_message_bubble.dart";

/// A floating call-to-action pinned below the top bar when the session has a
/// pending question or permission. Rendered as a semantic-tinted liquid-glass
/// card (brand for questions, success for permissions) so it pops over the chat
/// while sharing the glass language of the background-tasks card and the
/// composer pills below.
class SessionDetailPendingBanner extends StatelessWidget {
  final IconData icon;

  /// Semantic surface colour for the glass tint — applied with reduced alpha so
  /// the card stays frosted and the chat refracts through its edges.
  final Color backgroundColor;
  final Color foregroundColor;
  final String label;
  final VoidCallback onTap;

  const SessionDetailPendingBanner({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GlassContainer(
        useOwnLayer: true,
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.zero,
        shape: const LiquidRoundedSuperellipse(borderRadius: 20),
        settings: LiquidGlassSettings(glassColor: backgroundColor.withValues(alpha: 0.6)),
        child: GlassListTile(
          onTap: onTap,
          showDivider: false,
          leading: Icon(icon, size: 20, color: foregroundColor),
          title: Text(label),
          titleStyle: prego.textTheme.textMd.bold.copyWith(color: foregroundColor),
          trailing: Icon(Icons.chevron_right, size: 20, color: foregroundColor),
        ),
      ),
    );
  }
}

class SessionDetailQueuedMessagesSection extends StatelessWidget {
  final List<QueuedSessionSubmission> messages;

  const SessionDetailQueuedMessagesSection({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < messages.length; i++)
          QueuedMessageBubble(
            submission: messages[i],
            onCancel: () => context.read<SessionDetailCubit>().cancelQueuedMessage(i),
          ),
      ],
    );
  }
}

class SessionDetailErrorView extends StatelessWidget {
  final RemoteFailureReason reason;
  final VoidCallback onRetry;

  const SessionDetailErrorView({super.key, required this.reason, required this.onRetry});

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
