import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";
import "queued_message_bubble.dart";

class SessionDetailTitle extends StatelessWidget {
  final SessionDetailState state;
  final String fallbackTitle;

  const SessionDetailTitle({super.key, required this.state, required this.fallbackTitle});

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (state) {
      SessionDetailLoaded(:final agent, :final modelID) => [?agent, ?modelID].join(" · "),
      _ => "",
    };
    final title = switch (state) {
      SessionDetailLoaded(:final sessionTitle) when sessionTitle != null => sessionTitle,
      _ => fallbackTitle,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class SessionDetailPendingBanner extends StatelessWidget {
  final IconData icon;
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
    return Material(
      elevation: 2,
      color: backgroundColor,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: foregroundColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: foregroundColor),
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: foregroundColor),
            ],
          ),
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
  final ApiError error;
  final VoidCallback onRetry;

  const SessionDetailErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(loc.sessionDetailErrorTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_describeError(loc: loc, error: error), textAlign: TextAlign.center),
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

  String _describeError({required AppLocalizations loc, required ApiError error}) => switch (error) {
    NotAuthenticatedError() => loc.apiErrorNotAuthenticated,
    NonSuccessCodeError(:final errorCode, :final rawErrorString) => rawErrorString != null
        ? loc.connectErrorNonSuccessCodeWithBody(errorCode, rawErrorString)
        : loc.connectErrorNonSuccessCode(errorCode),
    DartHttpClientError(:final innerError) => loc.connectErrorConnectionFailed(innerError.toString()),
    JsonParsingError() => loc.connectErrorUnexpectedFormat,
    EmptyResponseError() => loc.connectErrorUnexpectedFormat,
    GenericError() => loc.connectErrorUnknown,
  };
}
