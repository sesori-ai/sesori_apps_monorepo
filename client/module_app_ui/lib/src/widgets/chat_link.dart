import "package:flutter/rendering.dart" show SelectedContent;
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:markdown/markdown.dart" as md;
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

/// Renders every Markdown link in chat as one inline [ChatLink]: an icon and a
/// short label in the link colour, as [presentChatLink] describes it.
class ChatLinkMarkdownBuilder({required final MarkdownTapLinkCallback onTapLink}) extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final href = element.attributes["href"];
    // Image links keep the default rendering so the image still shows.
    final hasImage = element.children?.any((child) => child is md.Element && child.tag == "img") ?? false;
    if (href == null || hasImage) return null;
    final text = element.textContent;
    // The surrounding text's size and weight, in the link colour.
    final style = (parentStyle ?? preferredStyle)?.copyWith(
      color: preferredStyle?.color,
      decoration: TextDecoration.none,
    );
    return Text.rich(
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: ChatLink(
          href: href,
          presentation: presentChatLink(href: href, text: text),
          style: style,
          onTap: () => onTapLink(text, href, element.attributes["title"] ?? ""),
        ),
      ),
    );
  }
}

/// A link in chat. A press dims it, a desktop hover shows the full [href], and
/// selecting any part of it copies [href].
class const ChatLink({
  super.key,
  required final String href,
  required final ChatLinkPresentation presentation,
  required final TextStyle? style,
  required final VoidCallback onTap,
}) extends StatefulWidget {
  @override
  State<ChatLink> createState() => _ChatLinkState();
}

class _ChatLinkState() extends State<ChatLink> {
  late final _selection = _CopiesHrefSelectionDelegate(href: widget.href);
  bool _isPressed = false;

  @override
  void didUpdateWidget(covariant ChatLink oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selection.href = widget.href;
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _setPressed({required bool isPressed}) {
    if (_isPressed != isPressed) setState(() => _isPressed = isPressed);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final color = style.color;
    final iconSize = (style.fontSize ?? 14) + 1;
    final icon = switch (widget.presentation) {
      ChatFileLinkPresentation(:final badge?) => _FileTypeBadge(badge: badge, size: iconSize, color: color),
      ChatFileLinkPresentation() => Icon(TablerRegular.file, size: iconSize, color: color),
      ChatGitHubLinkPresentation() => Icon(TablerRegular.brand_github, size: iconSize, color: color),
      ChatWebLinkPresentation() => Icon(TablerRegular.world, size: iconSize, color: color),
      ChatPlainLinkPresentation() => null,
    };
    return Tooltip(
      message: widget.href,
      // Hover still shows it on desktop; a long press stays free for selection.
      triggerMode: TooltipTriggerMode.manual,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => _setPressed(isPressed: true),
          onTapUp: (_) => _setPressed(isPressed: false),
          onTapCancel: () => _setPressed(isPressed: false),
          child: AnimatedOpacity(
            opacity: _isPressed ? 0.5 : 1,
            duration: const Duration(milliseconds: 100),
            child: SelectionContainer(
              delegate: _selection,
              child: Text.rich(
                TextSpan(
                  style: style,
                  children: [
                    if (icon != null)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(padding: const EdgeInsetsDirectional.only(end: 4), child: icon),
                      ),
                    TextSpan(text: widget.presentation.label),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The file type as text in a small rounded square of the link colour.
class const _FileTypeBadge({
  required final FileTypeBadge badge,
  required final double size,
  required final Color? color,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      child: FittedBox(
        child: Text(
          badge.label,
          style: TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w700,
            height: 1,
            color: context.prego.colors.bgSurface1,
          ),
        ),
      ),
    );
  }
}

/// Copies the link's full target, rather than its short label, whenever any
/// part of the link is selected.
class _CopiesHrefSelectionDelegate({required var String href}) extends StaticSelectionContainerDelegate {
  @override
  SelectedContent? getSelectedContent() => super.getSelectedContent() == null ? null : SelectedContent(plainText: href);
}
