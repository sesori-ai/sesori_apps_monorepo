import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:go_router/go_router.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/extensions/text_style_x.dart";
import "../../../core/widgets/copy_icon_button.dart";
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

  /// Status-bar inset captured from the presenting context. The modal route
  /// (`useSafeArea: false`) strips the top inset from BOTH `padding` and
  /// `viewPadding` in the sheet's own MediaQuery, so it must be measured
  /// before presenting and threaded through.
  final double topInset;

  const PermissionModal({
    super.key,
    required this.permission,
    required this.onReply,
    required this.topInset,
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
    // Capture before presenting: inside the route the top inset reads as 0.
    final topInset = MediaQuery.paddingOf(context).top;
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
        topInset: topInset,
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
    final screenHeight = MediaQuery.heightOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // Mirror the inset PregoBottomSheet adds below the body so the cap below
    // leaves the pinned action row on screen.
    final bottomInset = keyboard > 0 ? keyboard : MediaQuery.paddingOf(context).bottom;
    // Cap the body just under the sheet's own cap: a long description then
    // scrolls inside its Flexible slot while the action row stays pinned,
    // instead of pushing the (blocking) actions below the fold.
    final maxBody = screenHeight - topInset - PregoBottomSheet.contentTopInset - bottomInset;

    return PregoBottomSheet(
      title: context.loc.diffPermissionRequestTitle,
      topInset: topInset,
      // Closing the sheet answers the assistant: the X rejects, matching the
      // explicit reject button.
      onClose: () => _reply(context, reply: PermissionReply.reject),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: math.max(maxBody, screenHeight * 0.3)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A long request scrolls as one card while the blocking actions
            // remain pinned below it.
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  key: const Key("permission-detail-card"),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: prego.colors.bgSurface1,
                    borderRadius: BorderRadius.circular(prego.radius.xl),
                    border: Border.all(color: prego.colors.borderSecondary),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: prego.spacing.lg,
                          vertical: prego.spacing.md,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: prego.colors.bgBrandPrimary,
                                borderRadius: BorderRadius.circular(prego.radius.md),
                              ),
                              child: Icon(
                                TablerRegular.terminal,
                                size: 16,
                                color: prego.colors.textBrandPrimary,
                              ),
                            ),
                            SizedBox(width: prego.spacing.md),
                            Expanded(
                              child: Text(
                                permission.tool,
                                style: prego.textTheme.textSm.bold.monospace,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        key: const Key("permission-request-detail"),
                        width: double.infinity,
                        padding: EdgeInsetsDirectional.only(
                          start: prego.spacing.lg,
                          top: prego.spacing.lg,
                          end: prego.spacing.xs,
                          bottom: prego.spacing.lg,
                        ),
                        decoration: BoxDecoration(
                          color: prego.colors.bgQuaternary,
                          border: Border(top: BorderSide(color: prego.colors.borderSecondary)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: MarkdownBody(
                                data: permission.description,
                                selectable: true,
                                onTapLink: handleMarkdownLinkTap,
                                styleSheet: buildSessionMarkdownStyleSheet(
                                  prego: prego,
                                  paragraphStyle: prego.textTheme.textSm.regular
                                      .copyWith(color: prego.colors.textPrimary)
                                      .monospace,
                                ),
                              ),
                            ),
                            SizedBox(width: prego.spacing.xs),
                            CopyIconButton(
                              text: permission.description,
                              tooltip: context.loc.sessionDetailCopy,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
      ),
    );
  }
}
