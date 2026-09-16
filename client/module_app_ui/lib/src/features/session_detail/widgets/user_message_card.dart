import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../widgets/markdown_styles.dart";
import "../session_detail_markdown_link_handler.dart";
import "attachment_collection_widget.dart";
import "text_part_widget.dart" show MarkdownMessageImage;

class const UserMessageCard({super.key, required final MessageWithParts message}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = message.parts.whereType<MessagePartText>().map((part) => part.text).join("\n");
    final attachments = message.parts
        .whereType<MessagePartFile>()
        .map((part) => part.attachment)
        .whereType<MessageAttachment>()
        .toList();

    return UserMessageBubble(
      markdown: text.isEmpty ? null : text,
      attachments: [
        AttachmentCollectionWidget(
          sessionId: message.info.sessionID,
          attachments: attachments,
        ),
      ],
      outlined: false,
      transitionDuration: Duration.zero,
    );
  }
}

/// The shared surface and Markdown body for settled and queued user messages.
class const UserMessageBubble({
  super.key,
  required final String? markdown,
  required final List<Widget> attachments,
  required final bool outlined,
  required final Duration transitionDuration,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final markdown = this.markdown;

    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: .centerRight,
        child: AnimatedContainer(
          duration: transitionDuration,
          curve: Curves.easeInOutCubic,
          margin: const EdgeInsets.symmetric(
            horizontal: PregoSpacing.xl,
            vertical: PregoSpacing.xs,
          ),
          padding: const EdgeInsets.all(10),
          constraints: BoxConstraints(
            maxWidth: (constraints.maxWidth - PregoSpacing.xl * 2) * 0.76,
          ),
          decoration: BoxDecoration(
            color: prego.colors.bgSurface2,
            borderRadius: BorderRadius.circular(PregoRadius.xl),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PregoRadius.xl),
            border: Border.all(
              color: prego.colors.borderBrand.withValues(alpha: outlined ? 0.55 : 0),
            ),
          ),
          child: Column(
            crossAxisAlignment: .end,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...attachments,
              if (markdown != null)
                PregoReadableSelectionArea(
                  child: MarkdownBody(
                    data: markdown,
                    selectable: false,
                    softLineBreak: true,
                    onTapLink: buildSessionDetailMarkdownLinkTapHandler(context: context),
                    imageBuilder: (uri, title, alt) => _userMarkdownImage(
                      context: context,
                      uri: uri,
                      semanticLabel: alt,
                    ),
                    styleSheet: buildChatMessageMarkdownStyleSheet(prego: prego),
                    blockSyntaxes: sessionMarkdownBlockSyntaxes,
                    builders: buildSessionMarkdownBuilders(
                      highlightEnabled: true,
                      copyTooltip: context.loc.sessionDetailCopy,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userMarkdownImage({
    required BuildContext context,
    required Uri uri,
    required String? semanticLabel,
  }) {
    final scheme = uri.scheme.toLowerCase();
    final isSafeRemote = (scheme == "http" || scheme == "https") && uri.host.isNotEmpty && uri.userInfo.isEmpty;
    if (!isSafeRemote) {
      return MarkdownMessageImage(uri: uri, semanticLabel: semanticLabel);
    }

    final prego = context.prego;
    final normalizedLabel = semanticLabel?.trim();
    final label = normalizedLabel == null || normalizedLabel.isEmpty
        ? context.loc.sessionDetailImageOpen
        : normalizedLabel;
    final handleLink = buildSessionDetailMarkdownLinkTapHandler(context: context);
    return TextButton.icon(
      onPressed: () => handleLink(label, uri.toString(), ""),
      icon: const Icon(TablerRegular.photo, size: 16),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: TextButton.styleFrom(
        foregroundColor: prego.colors.textPrimary,
        backgroundColor: prego.colors.textPrimary.withValues(alpha: 0.08),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: PregoSpacing.lg,
          vertical: PregoSpacing.md,
        ),
        textStyle: prego.textTheme.textSm.medium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PregoRadius.md),
          side: BorderSide(
            color: prego.colors.textPrimary.withValues(alpha: 0.24),
          ),
        ),
      ),
    );
  }
}
