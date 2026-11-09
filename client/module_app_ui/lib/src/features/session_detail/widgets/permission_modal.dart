import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../platform/external_link_opener.dart";
import "../../../utils/copy_text_to_clipboard.dart";
import "../../../widgets/markdown_styles.dart";
import "pending_request_auto_dismiss.dart";

/// Presents every supported tool permission using the shared Prego action sheet.
/// The backend's tool and description remain intact; this surface does not infer
/// permission kinds or offer reply scopes the request cannot accept.
class const PermissionModal({
  super.key,
  required final SesoriPermissionAsked permission,

  /// The harness and session asking, for a surface watching several; null when
  /// not known.
  required final String? requestedBy,

  /// The harness asking, named where Always approve says where its rule lives;
  /// null when not known.
  required final String? harnessName,
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
    required String? requestedBy,
    required String? harnessName,
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
        onResolved: null,
        child: PermissionModal(
          permission: permission,
          requestedBy: requestedBy,
          harnessName: harnessName,
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
    final loc = context.loc;
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    final copy = PregoCopyIconButton(
      onCopy: () => copyTextToClipboard(
        text: permission.description,
        operation: "permission description",
      ),
      tooltip: context.loc.sessionDetailCopy,
    );
    final description = MarkdownBody(
      data: permission.description,
      selectable: true,
      onTapLink: buildMarkdownLinkTapHandler(openExternalLink: openExternalLink),
      styleSheet:
          buildSessionMarkdownStyleSheet(
            prego: prego,
            paragraphStyle: prego.textTheme.code.copyWith(color: prego.colors.textPrimary),
          ).copyWith(
            codeblockDecoration: BoxDecoration(
              color: prego.colors.bgSurface1,
              borderRadius: BorderRadius.circular(prego.radius.md),
              border: Border.all(color: prego.colors.borderSecondary),
            ),
          ),
    );
    return _AlwaysStep(
      builder: (context, confirmingAlways, setConfirmingAlways) => PregoActionSheet(
        title: confirmingAlways ? loc.diffPermissionAlwaysTitle : loc.diffPermissionRequestTitle,
        topInset: topInset,
        // No keyboard default: a stray Return must never approve a command.
        actions: pointer
            ? _PointerPermissionActions(
                allowAlways: permission.allowAlways,
                harnessName: harnessName,
                confirmingAlways: confirmingAlways,
                onConfirmingAlwaysChanged: setConfirmingAlways,
                onReply: (reply) => _reply(context, reply: reply),
              )
            : Column(
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
        child: Container(
          key: const Key("permission-request-detail"),
          padding: EdgeInsets.all(prego.spacing.lg),
          decoration: BoxDecoration(
            color: prego.colors.bgSurface2,
            borderRadius: BorderRadius.circular(prego.radius.xl),
            border: Border.all(color: prego.colors.borderPrimary),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: pointer
                ? [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: prego.spacing.md,
                      children: [
                        Expanded(child: description),
                        copy,
                      ],
                    ),
                    SizedBox(height: prego.spacing.sm),
                    Text(
                      [permission.tool, ?requestedBy].join(" · "),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary),
                    ),
                  ]
                : [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            permission.tool,
                            style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textSecondary),
                          ),
                        ),
                        copy,
                      ],
                    ),
                    SizedBox(height: prego.spacing.md),
                    description,
                  ],
          ),
        ),
      ),
    );
  }
}

/// Whether a request is on its Always approve step.
class const _AlwaysStep({
  required final Widget Function(BuildContext context, bool confirmingAlways, ValueChanged<bool> set) builder,
}) extends StatefulWidget {
  @override
  State<_AlwaysStep> createState() => _AlwaysStepState();
}

class _AlwaysStepState() extends State<_AlwaysStep> {
  bool _confirmingAlways = false;

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _confirmingAlways, (value) => setState(() => _confirmingAlways = value));
}

/// A desktop permission request's decisions: Allow leads, and Always approve is a
/// deliberate second step that first says what it hands over.
class const _PointerPermissionActions({
  required final bool allowAlways,
  required final String? harnessName,
  required final bool confirmingAlways,
  required final ValueChanged<bool> onConfirmingAlwaysChanged,
  required final ValueChanged<PermissionReply> onReply,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    Widget button({
      required Key key,
      required String label,
      required PregoButtonsSolidHierarchy hierarchy,
      PregoButtonsSolidType type = PregoButtonsSolidType.regular,
      required VoidCallback onPressed,
    }) => PregoButtonsSolid(
      key: key,
      label: label,
      hierarchy: hierarchy,
      type: type,
      size: PregoButtonsSolidSize.md,
      onPressed: onPressed,
    );
    final Widget step;
    if (confirmingAlways) {
      step = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: prego.spacing.lg,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: prego.spacing.xs,
            children: [
              Text(
                loc.diffPermissionAlwaysConsequence,
                style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary),
              ),
              Text(
                switch (harnessName) {
                  final harness? => loc.diffPermissionAlwaysHintNamed(harness),
                  null => loc.diffPermissionAlwaysHint,
                },
                style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: prego.spacing.md,
            runSpacing: prego.spacing.md,
            children: [
              button(
                key: const Key("permission-always-back"),
                label: loc.diffPermissionAlwaysBack,
                hierarchy: PregoButtonsSolidHierarchy.secondary,
                onPressed: () => onConfirmingAlwaysChanged(false),
              ),
              button(
                key: const Key("permission-always-confirm"),
                label: loc.diffPermissionAlwaysAllow,
                hierarchy: PregoButtonsSolidHierarchy.primary,
                type: PregoButtonsSolidType.warning,
                onPressed: () => onReply(PermissionReply.always),
              ),
            ],
          ),
        ],
      );
    } else {
      step = Wrap(
        alignment: WrapAlignment.end,
        spacing: prego.spacing.md,
        runSpacing: prego.spacing.md,
        children: [
          if (allowAlways)
            button(
              key: const Key("permission-always"),
              label: loc.diffPermissionAlwaysAllowEllipsis,
              hierarchy: PregoButtonsSolidHierarchy.tertiary,
              onPressed: () => onConfirmingAlwaysChanged(true),
            ),
          button(
            key: const Key("permission-reject"),
            label: loc.diffPermissionReject,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            onPressed: () => onReply(PermissionReply.reject),
          ),
          button(
            key: const Key("permission-allow"),
            label: loc.diffPermissionOnce,
            hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
            onPressed: () => onReply(PermissionReply.once),
          ),
        ],
      );
    }
    // A shortcut or reduced motion changes step at once. The new step's words
    // arrive as the room for them opens below what is being reviewed.
    final instant = prefersReducedMotion(context) || pregoActivatedByKeyboard;
    return AnimatedSize(
      duration: instant ? Duration.zero : pregoPointerEnterDuration,
      reverseDuration: instant ? Duration.zero : pregoPointerExitDuration,
      curve: pregoPointerEnterCurve,
      alignment: Alignment.topCenter,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(confirmingAlways),
        tween: Tween(begin: instant ? 1 : 0, end: 1),
        duration: instant ? Duration.zero : const Duration(milliseconds: 120),
        curve: pregoPointerEnterCurve,
        builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
        child: step,
      ),
    );
  }
}
