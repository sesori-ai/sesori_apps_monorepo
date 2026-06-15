import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";

class QueuedMessageBubble extends StatelessWidget {
  final QueuedSessionSubmission submission;
  final VoidCallback onCancel;

  const QueuedMessageBubble({
    super.key,
    required this.submission,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          const Spacer(),
          Flexible(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: prego.colors.bgSuccessSecondary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: prego.colors.fgSuccessPrimary.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                crossAxisAlignment: .end,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 6),
                    child: Column(
                      crossAxisAlignment: .end,
                      children: [
                        Row(
                          mainAxisSize: .min,
                          children: [
                            Icon(
                              submission.isCommand ? Icons.terminal : Icons.schedule,
                              size: 14,
                              color: prego.colors.fgSuccessPrimary.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              submission.isCommand ? loc.sessionDetailQueuedCommand : loc.sessionDetailQueuedMessage,
                              style: prego.textTheme.textXs.medium.copyWith(
                                color: prego.colors.fgSuccessPrimary.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          submission.displayText,
                          style: prego.textTheme.textSm.regular.copyWith(
                            color: prego.colors.fgSuccessPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 6),
                    child: Row(
                      mainAxisSize: .min,
                      children: [
                        TextButton.icon(
                          onPressed: onCancel,
                          icon: const Icon(Icons.close, size: 14),
                          label: Text(loc.sessionDetailCancelQueued),
                          style: TextButton.styleFrom(
                            foregroundColor: prego.colors.borderPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: .zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: prego.textTheme.textXs.medium,
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
