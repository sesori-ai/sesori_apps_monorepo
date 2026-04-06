import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../../core/widgets/app_modal_bottom_sheet.dart";
import "../../../core/widgets/markdown_styles.dart";

/// Bottom sheet that presents a tool permission request from the AI assistant.
///
/// Displays the tool name and description, and offers three actions:
/// reject, allow once, or always allow.
class PermissionModal extends StatelessWidget {
  final SesoriPermissionAsked permission;
  final void Function({
    required String requestId,
    required String sessionId,
    required PermissionReply reply,
  })
  onReply;

  const PermissionModal({
    super.key,
    required this.permission,
    required this.onReply,
  });

  /// Opens the permission modal as a bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required SesoriPermissionAsked permission,
    required void Function({
      required String requestId,
      required String sessionId,
      required PermissionReply reply,
    })
    onReply,
  }) {
    return showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PermissionModal(
        permission: permission,
        onReply: onReply,
      ),
    );
  }

  void _reply(BuildContext context, {required PermissionReply reply}) {
    Navigator.of(context).pop();
    onReply(
      requestId: permission.requestID,
      sessionId: permission.sessionID,
      reply: reply,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header row
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 8, 12),
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Permission Request",
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => _reply(context, reply: PermissionReply.reject),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Body — constrained to avoid full-screen expansion
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                // Tool name
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.terminal,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        permission.tool,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: "monospace",
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                MarkdownBody(
                  data: permission.description,
                  selectable: true,
                  onTapLink: handleMarkdownLinkTap,
                  styleSheet: buildSessionMarkdownStyleSheet(
                    theme,
                    paragraphStyle: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                    onPressed: () => _reply(context, reply: PermissionReply.reject),
                    child: const Text("Reject"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reply(context, reply: PermissionReply.once),
                    child: const Text("Once"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _reply(context, reply: PermissionReply.always),
                    child: const Text("Always Allow"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
