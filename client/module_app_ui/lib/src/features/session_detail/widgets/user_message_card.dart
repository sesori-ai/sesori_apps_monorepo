import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../widgets/markdown_styles.dart";
import "../file_preview/file_reference_code_syntax.dart";
import "../session_detail_markdown_link_handler.dart";
import "attachment_collection_widget.dart";
import "sent_bubble_landing.dart";
import "user_prompt_markdown_image.dart";

class const UserMessageCard({
  super.key,
  required final MessageWithParts message,

  /// How long to fade the outline this message's bubble had while it waited, or
  /// null when it had none.
  required final Duration? outlineFade,
}) extends StatefulWidget {
  @override
  State<UserMessageCard> createState() => _UserMessageCardState();

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

class _UserMessageCardState() extends State<UserMessageCard> {
  late bool _outlined = widget.outlineFade != null;

  /// The row's next build no longer has an outline to fade, and this one still fades.
  late final Duration _transitionDuration = widget.outlineFade ?? Duration.zero;

  @override
  void initState() {
    super.initState();
    if (!_outlined) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _outlined = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    return UserMessageBubble(
      markdown: UserMessageCard.markdownOf(message: message),
      attachments: [UserMessageCard.attachmentsOf(message: message)],
      outlined: _outlined,
      transitionDuration: _transitionDuration,
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
        child: SentBubbleSlot(
          text: markdown,
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
    final onTapLink = buildSessionDetailMarkdownLinkTapHandler(context: context);
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
              onTapLink: onTapLink,
              imageBuilder: (uri, title, alt) =>
                  buildUserPromptMarkdownImage(context: context, uri: uri, semanticLabel: alt),
              styleSheet: buildChatMessageMarkdownStyleSheet(prego: context.prego),
              blockSyntaxes: sessionMarkdownBlockSyntaxes,
              inlineSyntaxes: sessionMarkdownInlineSyntaxes,
              builders: buildSessionMarkdownBuilders(
                highlightEnabled: true,
                copyTooltip: context.loc.sessionDetailCopy,
                onTapLink: onTapLink,
              ),
            ),
          ),
      ],
    );
  }
}
