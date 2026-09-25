import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../platform/external_link_opener.dart";
import "pending_request_auto_dismiss.dart";
import "permission_request_details.dart";

/// Presents every supported tool permission using the shared Prego action sheet.
/// The backend's tool and description remain intact; this surface does not infer
/// permission kinds or offer reply scopes the request cannot accept.
class const PermissionModal({
  super.key,
  required final SesoriPermissionAsked permission,
  required final void Function({
    required String requestId,
    required String sessionId,
    required PermissionReply reply,
  })
  onReply,

  /// Status-bar inset captured before the modal route removes it.
  required final double topInset,
  required final ExternalLinkOpener openExternalLink,
}) extends StatelessWidget {
  /// Scrim and swipe dismissal leave the request pending. Only an explicit
  /// decision answers it; external settlement closes it without another reply.
  static Future<void> show(
    BuildContext context, {
    required SesoriPermissionAsked permission,
    required void Function({
      required String requestId,
      required String sessionId,
      required PermissionReply reply,
    })
    onReply,
    required Stream<bool> isPendingStream,
    required bool Function() isPending,
    required ExternalLinkOpener openExternalLink,
  }) {
    final topInset = MediaQuery.paddingOf(context).top;
    return showPregoModalRoute<void>(
      context: context,
      builder: (_) => PendingRequestAutoDismiss(
        isPendingStream: isPendingStream,
        isPending: isPending,
        child: PermissionModal(
          permission: permission,
          onReply: onReply,
          topInset: topInset,
          openExternalLink: openExternalLink,
        ),
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
    return PregoActionSheet(
      title: switch (permission.details) {
        GenericPermissionDetails() => context.loc.diffPermissionRequestTitle,
        CommandPermissionDetails() => context.loc.permissionCommandTitle,
        FileChangesPermissionDetails() => context.loc.permissionFilesTitle,
        NetworkPermissionDetails() => context.loc.permissionNetworkTitle,
      },
      topInset: topInset,
      actions: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: prego.spacing.xl,
        children: [
          PregoButtonsSolid(
            label: context.loc.diffPermissionOnce,
            hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
            size: PregoButtonsSolidSize.lg,
            fullWidth: true,
            onPressed: () => _reply(context, reply: PermissionReply.once),
          ),
          if (permission.allowAlways)
            PregoButtonsSolid(
              label: context.loc.diffPermissionAlwaysAllow,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.lg,
              fullWidth: true,
              onPressed: () => _reply(context, reply: PermissionReply.always),
            ),
          PregoButtonsSolid(
            label: context.loc.diffPermissionReject,
            hierarchy: PregoButtonsSolidHierarchy.tertiary,
            size: PregoButtonsSolidSize.lg,
            fullWidth: true,
            onPressed: () => _reply(context, reply: PermissionReply.reject),
          ),
        ],
      ),
      child: PermissionRequestDetails(permission: permission, openExternalLink: openExternalLink),
    );
  }
}
