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
    return UserMessageBubble(
      markdown: markdownOf(message: message),
      attachments: [attachmentsOf(message: message)],
      outlined: false,
      transitionDuration: Duration.zero,
    );
  }

  /// The message's text, or null when it has only attachments.
  static String? markdownOf({required MessageWithParts message}) {
    final text = message.parts.whereType<MessagePartText>().map((part) => part.text).join("\n");
    return text.isEmpty ? null : text;
  }

  /// The message's attachments, as its bubble shows them.
  static Widget attachmentsOf({required MessageWithParts message}) => AttachmentCollectionWidget(
    sessionId: message.info.sessionID,
    attachments: message.parts
        .whereType<MessagePartFile>()
        .map((part) => part.attachment)
        .whereType<MessageAttachment>()
        .toList(),
  );
}

/// The shared surface and Markdown body for settled and queued user messages.
class const UserMessageBubble({
  super.key,
  required final String? markdown,
  required final List<Widget> attachments,
  required final bool outlined,
  required final Duration transitionDuration,
}) extends StatelessWidget {
  /// Space around the surface, inside the row.
  static const margin = EdgeInsets.symmetric(horizontal: PregoSpacing.xl, vertical: PregoSpacing.xs);

  /// Space between the surface's edge and its content.
  static const double padding = 10;

  static const double radius = PregoRadius.xl;

  /// The widest the content may be in a row [rowWidth] wide.
  static double maxContentWidth({required double rowWidth}) => (rowWidth - margin.horizontal) * 0.76 - padding * 2;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: .centerRight,
        child: AnimatedContainer(
          duration: transitionDuration,
          curve: Curves.easeInOutCubic,
          margin: margin,
          padding: const EdgeInsets.all(padding),
          constraints: BoxConstraints(
            maxWidth: maxContentWidth(rowWidth: constraints.maxWidth) + padding * 2,
          ),
          decoration: BoxDecoration(
            color: prego.colors.bgSurface2,
            borderRadius: BorderRadius.circular(radius),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: prego.colors.borderBrand.withValues(alpha: outlined ? 0.55 : 0),
            ),
          ),
          child: UserMessageBubbleContent(markdown: markdown, attachments: attachments),
        ),
      ),
    );
  }
}

/// A user bubble's content without its surface: the attachments over the
/// Markdown body. The pinned prompt paints this same content on its own
/// surface, so a pin and the bubble it stands in for are pixel-identical.
class const UserMessageBubbleContent({
  super.key,
  required final String? markdown,
  required final List<Widget> attachments,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final markdown = this.markdown;
    return Column(
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
              imageBuilder: (uri, title, alt) =>
                  buildUserPromptMarkdownImage(context: context, uri: uri, semanticLabel: alt),
              styleSheet: buildChatMessageMarkdownStyleSheet(prego: context.prego),
              blockSyntaxes: sessionMarkdownBlockSyntaxes,
              builders: buildSessionMarkdownBuilders(
                highlightEnabled: true,
                copyTooltip: context.loc.sessionDetailCopy,
              ),
            ),
          ),
      ],
    );
  }
}
