import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:markdown/markdown.dart" as md;
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";
import "../utils/code_highlighter.dart";
import "../utils/copy_text_to_clipboard.dart";

/// [MarkdownBody.builders] entry for fenced code blocks (the `pre` element).
///
/// Returning a non-null widget here replaces flutter_markdown's default
/// `pre` rendering (flat monospace in a box) with a themed [CodeBlock]:
/// language label, copy button and optional syntax highlighting.
///
/// `pre` is always a block tag, so this never affects inline code (single
/// backticks), which keeps flowing through the default `code` style.
class CodeBlockMarkdownBuilder({
  /// When false (e.g. while the message is still streaming) the block renders
  /// as plain monospace to avoid re-highlighting on every token delta.
  required final bool highlightEnabled,
  final String? copyTooltip,
}) extends MarkdownElementBuilder {
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
      isFullView: false,
    );
  }
}

/// [MarkdownBody.builders] entry for fenced code blocks inside a preview of a
/// message, such as the pinned prompt: a still [CodeBlockPreview] instead of
/// the interactive [CodeBlock].
class CodeBlockPreviewMarkdownBuilder() extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return CodeBlockPreview(code: _extractCode(element), language: _extractLanguage(element));
  }
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

/// The label a block's header shows for [language].
String _languageLabelOf({required String? language}) => (language == null || language.isEmpty) ? "code" : language;

/// A still picture of a fenced code block: the language label over the first
/// lines of the code, with nothing to press and nothing to scroll.
///
/// [CodeBlock] cannot serve a preview. Its copy and open-all controls sit under
/// a surface whose own tap does something else, so they would look pressable
/// and do the wrong thing; and its horizontal scroll view reports its metrics
/// to whatever listens above it, which for the pinned prompt is the
/// transcript's list, reading them as its own scroll.
class const CodeBlockPreview({super.key, required final String code, required final String? language})
    extends StatelessWidget {
  /// More than the few lines a preview can show, so the surrounding cut, not
  /// this, is what ends it.
  static const _previewLines = 4;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final lines = code.split("\n");
    final shownCode = lines.length > _previewLines ? lines.take(_previewLines).join("\n") : code;

    // The markdown style sheet's code block decoration draws the box around this.
    return Column(
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 8, end: 4, top: 4),
          child: Text(
            _languageLabelOf(language: language),
            style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textSecondary),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 8),
          child: Text(
            shownCode,
            softWrap: false,
            style: prego.textTheme.code.copyWith(color: prego.colors.textPrimary),
          ),
        ),
      ],
    );
  }
}

/// A themed fenced-code-block widget: a header with the language label and a
/// one-tap copy button, over horizontally scrollable, optionally
/// syntax-highlighted code.
///
/// A block longer than [_cappedLines] shows its first lines under a fade and
/// opens whole in a modal, so one long block cannot swallow the transcript.
class const CodeBlock({
  super.key,
  required final String code,
  required final String? language,
  final bool highlightEnabled = true,
  final String? copyTooltip,

  /// The whole block inside the modal, which already titles the language.
  required final bool isFullView,
}) extends StatefulWidget {
  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState() extends State<CodeBlock> {
  static const int _cappedLines = 12;

  (Brightness, String?, String, TextStyle)? _cacheKey;
  TextSpan? _cachedSpan;

  /// Highlights once per distinct (brightness, language, code, baseStyle)
  /// tuple so unrelated rebuilds (follow/detach, theme-independent setState)
  /// reuse the previous result instead of re-tokenizing. baseStyle is part of
  /// the key so a same-brightness color-token or text-scale change still
  /// invalidates the cache.
  TextSpan? _spanFor({required String code, required Brightness brightness, required TextStyle baseStyle}) {
    if (!widget.highlightEnabled) return null;
    final key = (brightness, widget.language, code, baseStyle);
    if (key == _cacheKey) return _cachedSpan;
    _cacheKey = key;
    return _cachedSpan = CodeHighlighter.highlight(
      code: code,
      language: widget.language,
      brightness: brightness,
      baseStyle: baseStyle,
    );
  }

  String get _languageLabel => _languageLabelOf(language: widget.language);

  void _openAll() {
    showPregoModal<void>(
      context: context,
      title: _languageLabel,
      width: PregoModalWidth.code,
      // A modal route sits outside the transcript's selection area, so it brings its own.
      builder: (_) => PregoReadableSelectionArea(
        child: SingleChildScrollView(
          child: CodeBlock(
            code: widget.code,
            language: widget.language,
            copyTooltip: widget.copyTooltip,
            isFullView: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final brightness = Theme.of(context).brightness;
    final baseStyle = prego.textTheme.code.copyWith(color: prego.colors.textPrimary);
    final lines = widget.code.split("\n");
    final isCapped = !widget.isFullView && lines.length > _cappedLines;
    final shownCode = isCapped ? lines.take(_cappedLines).join("\n") : widget.code;
    final span = _spanFor(code: shownCode, brightness: brightness, baseStyle: baseStyle);

    final codeView = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 8),
      child: span != null ? Text.rich(span) : Text(shownCode, style: baseStyle),
    );

    // The markdown style sheet's code block decoration draws the box around this.
    return Column(
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 8, end: 4, top: 4),
          child: Row(
            children: [
              Expanded(
                child: widget.isFullView
                    ? const SizedBox.shrink()
                    : Text(
                        _languageLabel,
                        style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textSecondary),
                      ),
              ),
              PregoCopyIconButton(
                onCopy: () => copyTextToClipboard(text: widget.code, operation: "code block"),
                tooltip: widget.copyTooltip,
              ),
            ],
          ),
        ),
        if (isCapped) ...[
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.black, Colors.transparent],
              stops: [0, 0.7, 1],
            ).createShader(bounds),
            child: codeView,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 4),
            // A button, so the action takes keyboard focus and Enter as well as a click.
            child: TextButton(
              onPressed: _openAll,
              style: TextButton.styleFrom(
                foregroundColor: prego.colors.textPrimary,
                padding: const EdgeInsetsDirectional.fromSTEB(8, 2, 8, 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PregoRadius.xs)),
                textStyle: prego.textTheme.textSm.medium,
              ),
              child: Text(context.loc.codeBlockOpenAll(lines.length)),
            ),
          ),
        ] else
          codeView,
      ],
    );
  }
}
