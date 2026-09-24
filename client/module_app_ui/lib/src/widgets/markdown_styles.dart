import "dart:async";

import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:markdown/markdown.dart" as md;
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../platform/external_link_opener.dart";
import "code_block.dart";

/// Creates a [MarkdownBody.onTapLink] handler backed by product-owned link
/// policy.
MarkdownTapLinkCallback buildMarkdownLinkTapHandler({required ExternalLinkOpener openExternalLink}) {
  // ignore: no_slop_linter/prefer_required_named_parameters, callback signature is defined by MarkdownBody.onTapLink
  return (String text, String? href, String title) {
    if (href == null) return;
    final uri = Uri.tryParse(href);
    if (uri == null || !_isAllowedMarkdownUri(uri)) return;
    unawaited(openExternalLink(url: uri, mode: UrlLaunchMode.externalApp).then<void>((_) {}));
  };
}

bool _isAllowedMarkdownUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  return switch (scheme) {
    "http" || "https" => uri.host.isNotEmpty && uri.userInfo.isEmpty,
    "mailto" => uri.path.isNotEmpty,
    _ => false,
  };
}

// ignore: no_slop_linter/prefer_required_named_parameters, paragraphStyle is an optional override
MarkdownStyleSheet buildSessionMarkdownStyleSheet({
  required PregoDesignSystem prego,
  TextStyle? paragraphStyle,
}) {
  return _withTablesAndRules(
    prego: prego,
    sheet: MarkdownStyleSheet(
      p: paragraphStyle ?? prego.textTheme.textSm.regular,
      // The renderer wraps every code block, a [CodeBlock] included, in this box,
      // so it is the only one.
      codeblockDecoration: _codeBlockDecoration(prego: prego),
      code: TextStyle(
        fontSize: 13,
        color: prego.colors.textPrimary,
      ).monospace,
      // The Material fallback fills quotes with the default purple palette's
      // light surface, which Prego leaves unset: unreadable in dark mode.
      blockquotePadding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
      blockquoteDecoration: _blockquoteDecoration(prego: prego),
    ),
  );
}

/// The same inset as a tool's output, so code reads alike wherever it appears.
BoxDecoration _codeBlockDecoration({required PregoDesignSystem prego}) => BoxDecoration(
  color: prego.colors.bgQuaternary,
  borderRadius: BorderRadius.circular(PregoRadius.xs),
);

BoxDecoration _blockquoteDecoration({required PregoDesignSystem prego}) => BoxDecoration(
  border: Border(left: BorderSide(color: prego.colors.fgQuaternary, width: 3)),
);

/// Explicit so no surface falls back to the SDK's Material defaults: row lines
/// under a start-aligned header, and a hairline rule.
MarkdownStyleSheet _withTablesAndRules({required PregoDesignSystem prego, required MarkdownStyleSheet sheet}) {
  final line = BorderSide(color: prego.colors.borderSecondary);
  return sheet.copyWith(
    tableBorder: TableBorder(horizontalInside: line),
    tableHeadAlign: TextAlign.start,
    tableCellsPadding: const EdgeInsets.only(right: PregoSpacing.lg, top: 6, bottom: 6),
    horizontalRuleDecoration: BoxDecoration(border: Border(top: line)),
  );
}

/// Figma chat typography shared by outgoing bubbles and assistant responses.
MarkdownStyleSheet buildChatMessageMarkdownStyleSheet({required PregoDesignSystem prego}) {
  final foreground = prego.colors.textPrimary;
  final body = prego.textTheme.textSm.regular.copyWith(
    color: foreground,
    letterSpacing: 0.14,
  );
  final base = buildSessionMarkdownStyleSheet(
    prego: prego,
    paragraphStyle: body,
  );

  return base.copyWith(
    a: body.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: foreground,
    ),
    // Chat renders fenced blocks as a [CodeBlock], so this only reaches inline code.
    code: base.code?.copyWith(color: foreground, backgroundColor: prego.colors.bgTertiary),
    h1: prego.textTheme.textXl.bold.copyWith(color: foreground),
    h2: prego.textTheme.textLg.bold.copyWith(color: foreground),
    h3: prego.textTheme.textMd.bold.copyWith(color: foreground),
    h4: prego.textTheme.textSm.bold.copyWith(color: foreground),
    h5: prego.textTheme.textSm.bold.copyWith(color: foreground),
    h6: prego.textTheme.textSm.bold.copyWith(color: foreground),
    em: body.copyWith(fontStyle: FontStyle.italic),
    strong: body.copyWith(fontWeight: FontWeight.bold),
    del: body.copyWith(decoration: TextDecoration.lineThrough),
    blockquote: body,
    checkbox: body,
    listBullet: body,
    tableHead: body.copyWith(fontWeight: FontWeight.bold),
    tableBody: body,
  );
}

/// Custom [MarkdownBody.builders] for session chat markdown. Replaces the
/// default fenced-code-block rendering with a syntax-highlighted, copyable
/// [CodeBlock]. Pass `highlightEnabled: false` while a message is streaming so
/// code is not re-tokenized on every token delta.
Map<String, MarkdownElementBuilder> buildSessionMarkdownBuilders({
  required bool highlightEnabled,
  required String? copyTooltip,
}) {
  return <String, MarkdownElementBuilder>{
    "pre": CodeBlockMarkdownBuilder(
      highlightEnabled: highlightEnabled,
      copyTooltip: copyTooltip,
    ),
  };
}

/// Renders a raw HTML block as a code block instead of dropping it.
///
/// The default [md.HtmlBlockSyntax] emits a bare text node under the document
/// root, and the Markdown widget skips text directly under the root, so a
/// pasted HTML page or error body silently disappears from the message. Chat
/// text is never trusted markup anyway, so showing the source is the honest
/// rendering, and a code block keeps its whitespace and stays copyable.
class const _LiteralHtmlBlockSyntax() extends md.HtmlBlockSyntax {
  @override
  md.Node parse(md.BlockParser parser) => md.Element("pre", [md.Text(super.parse(parser).textContent.trim())]);
}

/// Custom [MarkdownBody.blockSyntaxes] for session chat markdown.
const sessionMarkdownBlockSyntaxes = <md.BlockSyntax>[_LiteralHtmlBlockSyntax()];

/// Style sheet for the legal documents (terms, privacy) the backend serves as
/// markdown: a long-form reading layout with headings, numbered clauses and the
/// occasional inline link.
MarkdownStyleSheet buildLegalMarkdownStyleSheet({required PregoDesignSystem prego}) {
  final body = prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary);
  return _withTablesAndRules(
    prego: prego,
    sheet: MarkdownStyleSheet(
      h1: prego.textTheme.textXl.bold.copyWith(color: prego.colors.textPrimary),
      h2: prego.textTheme.textMd.bold.copyWith(color: prego.colors.textPrimary),
      h3: prego.textTheme.textSm.bold.copyWith(color: prego.colors.textPrimary),
      h1Padding: const EdgeInsets.only(bottom: PregoSpacing.md),
      h2Padding: const EdgeInsets.only(top: PregoSpacing.x2l, bottom: PregoSpacing.xxs),
      h3Padding: const EdgeInsets.only(top: PregoSpacing.lg, bottom: PregoSpacing.xxs),
      p: body,
      listBullet: body,
      strong: body.copyWith(color: prego.colors.textPrimary, fontWeight: FontWeight.w600),
      a: body.copyWith(
        color: prego.colors.textBrandSecondary,
        decoration: TextDecoration.underline,
      ),
      code: body.copyWith(color: prego.colors.textPrimary).monospace,
      codeblockDecoration: _codeBlockDecoration(prego: prego),
      blockquotePadding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
      blockquoteDecoration: _blockquoteDecoration(prego: prego),
    ),
  );
}

MarkdownStyleSheet buildAgreementMarkdownStyleSheet({required PregoDesignSystem prego}) {
  final paragraph = prego.textTheme.textSm.regular.copyWith(
    color: prego.colors.textPrimary,
  );
  return MarkdownStyleSheet(
    p: paragraph,
    a: paragraph.copyWith(
      decoration: TextDecoration.underline,
    ),
    textAlign: WrapAlignment.center,
    pPadding: EdgeInsets.zero,
    blockSpacing: 0,
  );
}
