import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:go_router/go_router.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/extensions/text_style_x.dart";
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
  ///
  /// Presents a [PregoBottomSheet] directly (not via [showPregoBottomSheet])
  /// so the header close button rejects the request instead of silently
  /// dismissing it.
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // PregoBottomSheet paints the rounded surface; keep the route
      // transparent. The sheet caps itself below the status bar.
      backgroundColor: Colors.transparent,
      useSafeArea: false,
      builder: (_) => PermissionModal(
        permission: permission,
        onReply: onReply,
      ),
    );
  }

  void _reply(BuildContext context, {required PermissionReply reply}) {
    context.pop();
    onReply(
      requestId: permission.requestID,
      sessionId: permission.sessionID,
      reply: reply,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return PregoBottomSheet(
      title: context.loc.diffPermissionRequestTitle,
      // The modal route strips the top padding from the sheet's MediaQuery;
      // viewPadding survives, so read the status-bar inset from it.
      topInset: MediaQuery.viewPaddingOf(context).top,
      // Closing the sheet answers the assistant: the X rejects, matching the
      // explicit reject button.
      onClose: () => _reply(context, reply: PermissionReply.reject),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tool name
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: prego.colors.bgQuaternary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.terminal,
                  size: 16,
                  color: prego.colors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  permission.tool,
                  style: prego.textTheme.textSm.bold
                      .copyWith(
                        fontWeight: FontWeight.bold,
                      )
                      .monospace,
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
              prego: prego,
              paragraphStyle: prego.textTheme.textSm.regular,
            ),
          ),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: prego.colors.fgErrorPrimary,
                    side: BorderSide(color: prego.colors.fgErrorPrimary),
                  ),
                  onPressed: () => _reply(context, reply: PermissionReply.reject),
                  child: Text(context.loc.diffPermissionReject),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _reply(context, reply: PermissionReply.once),
                  child: Text(context.loc.diffPermissionOnce),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => _reply(context, reply: PermissionReply.always),
                  child: Text(context.loc.diffPermissionAlwaysAllow),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
