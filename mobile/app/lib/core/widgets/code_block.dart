import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:markdown/markdown.dart" as md;
import "package:theme_zyra/module_zyra.dart";

import "../extensions/text_style_x.dart";
import "../utils/code_highlighter.dart";
import "copy_icon_button.dart";

/// [MarkdownBody.builders] entry for fenced code blocks (the `pre` element).
///
/// Returning a non-null widget here replaces flutter_markdown's default
/// `pre` rendering (flat monospace in a box) with a themed [CodeBlock]:
/// language label, copy button and optional syntax highlighting.
///
/// `pre` is always a block tag, so this never affects inline code (single
/// backticks), which keeps flowing through the default `code` style.
class CodeBlockMarkdownBuilder extends MarkdownElementBuilder {
  /// When false (e.g. while the message is still streaming) the block renders
  /// as plain monospace to avoid re-highlighting on every token delta.
  final bool highlightEnabled;
  final String? copyTooltip;

  CodeBlockMarkdownBuilder({required this.highlightEnabled, this.copyTooltip});

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return CodeBlock(
      code: _extractCode(element),
      language: _extractLanguage(element),
      highlightEnabled: highlightEnabled,
      copyTooltip: copyTooltip,
    );
  }

  /// Raw block text with the single trailing newline a fence carries removed.
  String _extractCode(md.Element element) {
    final raw = element.textContent;
    return raw.endsWith("\n") ? raw.substring(0, raw.length - 1) : raw;
  }

  /// Reads the language from the inner `<code class="language-xxx">` element.
  /// Indented (4-space) blocks and language-less fences return null.
  String? _extractLanguage(md.Element element) {
    for (final child in element.children ?? const <md.Node>[]) {
      if (child is md.Element && child.tag == "code") {
        const prefix = "language-";
        final cls = child.attributes["class"];
        if (cls != null && cls.startsWith(prefix)) {
          return cls.substring(prefix.length);
        }
      }
    }
    return null;
  }
}

/// A themed fenced-code-block widget: a header with the language label and a
/// one-tap copy button, over horizontally scrollable, optionally
/// syntax-highlighted code.
class CodeBlock extends StatefulWidget {
  final String code;
  final String? language;
  final bool highlightEnabled;
  final String? copyTooltip;

  const CodeBlock({
    super.key,
    required this.code,
    required this.language,
    this.highlightEnabled = true,
    this.copyTooltip,
  });

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  (Brightness, String?, String, TextStyle)? _cacheKey;
  TextSpan? _cachedSpan;

  /// Highlights once per distinct (brightness, language, code, baseStyle)
  /// tuple so unrelated rebuilds (follow/detach, theme-independent setState)
  /// reuse the previous result instead of re-tokenizing. baseStyle is part of
  /// the key so a same-brightness color-token or text-scale change still
  /// invalidates the cache.
  TextSpan? _spanFor({required Brightness brightness, required TextStyle baseStyle}) {
    if (!widget.highlightEnabled) return null;
    final key = (brightness, widget.language, widget.code, baseStyle);
    if (key == _cacheKey) return _cachedSpan;
    _cacheKey = key;
    return _cachedSpan = CodeHighlighter.highlight(
      code: widget.code,
      language: widget.language,
      brightness: brightness,
      baseStyle: baseStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final brightness = Theme.of(context).brightness;
    final baseStyle = const TextStyle(fontSize: 13, height: 1.4).monospace.copyWith(
      color: zyra.colors.textPrimary,
    );
    final span = _spanFor(brightness: brightness, baseStyle: baseStyle);
    final language = widget.language;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: zyra.colors.bgQuaternary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: zyra.colors.borderSecondary),
        ),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: zyra.colors.borderSecondary)),
              ),
              padding: const EdgeInsetsDirectional.only(start: 12, end: 4, top: 2, bottom: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      (language == null || language.isEmpty) ? "code" : language,
                      style: zyra.textTheme.textXs.medium.copyWith(
                        color: zyra.colors.textSecondary,
                      ),
                    ),
                  ),
                  CopyIconButton(text: widget.code, tooltip: widget.copyTooltip),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: span != null ? Text.rich(span) : Text(widget.code, style: baseStyle),
            ),
          ],
        ),
      ),
    );
  }
}
