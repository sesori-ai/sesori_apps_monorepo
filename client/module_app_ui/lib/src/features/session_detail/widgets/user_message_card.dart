import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../widgets/markdown_styles.dart";
import "../session_detail_markdown_link_handler.dart";
import "attachment_collection_widget.dart";
import "user_prompt_markdown_image.dart";

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
                    imageBuilder: (uri, title, alt) => buildUserPromptMarkdownImage(
                      context: context,
                      uri: uri,
                      semanticLabel: alt,
                      interactive: true,
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
}
