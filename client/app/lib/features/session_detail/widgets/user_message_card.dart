import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/markdown_styles.dart";
import "file_part_widget.dart";
import "text_part_widget.dart" show MarkdownMessageImage;

class UserMessageCard extends StatelessWidget {
  final MessageWithParts message;

  const UserMessageCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final text = message.parts
        .where((part) => part.type == MessagePartType.text)
        .map((part) => part.text ?? "")
        .join("\n");
    final attachments = message.parts
        .where((part) => part.type == MessagePartType.file)
        .map((part) => part.attachment)
        .whereType<MessageAttachment>()
        .toList();

    return UserMessageBubble(
      markdown: text.isEmpty ? null : text,
      attachments: [
        for (final attachment in attachments)
          FilePartWidget(sessionId: message.info.sessionID, attachment: attachment),
      ],
      outlined: false,
      transitionDuration: Duration.zero,
    );
  }
}

/// The shared surface and Markdown body for settled and queued user messages.
class UserMessageBubble extends StatelessWidget {
  final String? markdown;
  final List<Widget> attachments;
  final bool outlined;
  final Duration transitionDuration;

  const UserMessageBubble({
    super.key,
    required this.markdown,
    required this.attachments,
    required this.outlined,
    required this.transitionDuration,
  });

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
              SelectionArea(
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
