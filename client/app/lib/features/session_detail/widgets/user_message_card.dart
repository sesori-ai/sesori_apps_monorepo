import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/markdown_styles.dart";
import "../../../core/widgets/readable_selection_area.dart";
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

    return Align(
      alignment: .centerRight,
      child: AnimatedContainer(
        duration: transitionDuration,
        curve: Curves.easeInOutCubic,
        margin: const EdgeInsets.symmetric(
          horizontal: PregoSpacing.xl,
          vertical: PregoSpacing.xs,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: PregoSpacing.xl,
          vertical: PregoSpacing.lg,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        decoration: BoxDecoration(
          color: prego.colors.bgBrandPrimary,
          borderRadius: BorderRadius.circular(PregoRadius.x2l),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PregoRadius.x2l),
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
              ReadableSelectionArea(
                child: MarkdownBody(
                  data: markdown,
                  selectable: false,
                  softLineBreak: true,
                  onTapLink: handleMarkdownLinkTap,
                  imageBuilder: (uri, title, alt) => _userMarkdownImage(
                    context: context,
                    uri: uri,
                    semanticLabel: alt,
                  ),
                  styleSheet: buildUserMessageMarkdownStyleSheet(prego: prego),
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
    return TextButton.icon(
      onPressed: () => handleMarkdownLinkTap(label, uri.toString(), ""),
      icon: const Icon(TablerRegular.photo, size: 16),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: TextButton.styleFrom(
        foregroundColor: prego.colors.textBrandPrimary,
        backgroundColor: prego.colors.textBrandPrimary.withValues(alpha: 0.08),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: PregoSpacing.lg,
          vertical: PregoSpacing.md,
        ),
        textStyle: prego.textTheme.textSm.medium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PregoRadius.md),
          side: BorderSide(
            color: prego.colors.textBrandPrimary.withValues(alpha: 0.24),
          ),
        ),
      ),
    );
  }
}
