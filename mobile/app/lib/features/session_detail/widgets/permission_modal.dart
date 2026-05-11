import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:go_router/go_router.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../../core/extensions/build_context_x.dart";
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
    context.pop();
    onReply(
      requestId: permission.requestID,
      sessionId: permission.sessionID,
      reply: reply,
    );
  }

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;

    return Container(
      decoration: BoxDecoration(
        color: zyra.colors.bgPrimary,
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
                color: zyra.colors.borderSecondary,
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
                  color: zyra.colors.bgBrandSolid,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.loc.diffPermissionRequestTitle,
                    style: zyra.textTheme.textMd.bold,
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
                    color: zyra.colors.bgQuaternary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.terminal,
                        size: 16,
                        color: zyra.colors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        permission.tool,
                        style: zyra.textTheme.textSm.bold.copyWith(
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
                      zyra: zyra,
                      paragraphStyle: zyra.textTheme.textSm.regular,
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
                      foregroundColor: zyra.colors.fgErrorPrimary,
                      side: BorderSide(color: zyra.colors.fgErrorPrimary),
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
          ),
        ],
      ),
    );
  }
}
