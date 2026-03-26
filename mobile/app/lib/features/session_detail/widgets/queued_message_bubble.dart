import "package:flutter/material.dart";

import "../../../core/extensions/build_context_x.dart";

class QueuedMessageBubble extends StatelessWidget {
  final String text;
  final VoidCallback onCancel;

  const QueuedMessageBubble({
    super.key,
    required this.text,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          const Spacer(),
          Flexible(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                crossAxisAlignment: .end,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    child: Column(
                      crossAxisAlignment: .end,
                      children: [
                        Row(
                          mainAxisSize: .min,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: theme.colorScheme.onTertiaryContainer.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              loc.sessionDetailQueuedMessage,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onTertiaryContainer.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                    child: Row(
                      mainAxisSize: .min,
                      children: [
                        TextButton.icon(
                          onPressed: onCancel,
                          icon: const Icon(Icons.close, size: 14),
                          label: Text(loc.sessionDetailCancelQueued),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.outline,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: .zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: theme.textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
