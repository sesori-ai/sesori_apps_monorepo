import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/text_style_x.dart";
import "../external_link.dart";
import "code_block.dart";

/// Shared [MarkdownBody.onTapLink] handler that opens URLs in the system
/// browser via [openExternalLink].
// ignore: no_slop_linter/prefer_required_named_parameters, callback signature is defined by MarkdownBody.onTapLink
void handleMarkdownLinkTap(String text, String? href, String title) {
  if (href == null) return;
  final uri = Uri.tryParse(href);
  if (uri == null || !_isAllowedMarkdownUri(uri)) return;
  unawaited(openExternalLink(url: uri, mode: UrlLaunchMode.externalApp).then<void>((_) {}));
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
  return MarkdownStyleSheet(
    p: paragraphStyle ?? prego.textTheme.textSm.regular,
    codeblockDecoration: BoxDecoration(
      color: prego.colors.bgQuaternary,
      borderRadius: BorderRadius.circular(8),
    ),
    code: TextStyle(
      fontSize: 13,
      color: prego.colors.textPrimary,
    ).monospace,
  );
}

/// Session Markdown styled for the brand surface of an outgoing user bubble.
MarkdownStyleSheet buildUserMessageMarkdownStyleSheet({required PregoDesignSystem prego}) {
  final foreground = prego.colors.textBrandPrimary;
  final body = prego.textTheme.textSm.regular.copyWith(color: foreground);
  final base = buildSessionMarkdownStyleSheet(
    prego: prego,
    paragraphStyle: body,
  );

  return base.copyWith(
    a: body.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: foreground,
    ),
    code: base.code?.copyWith(color: foreground),
    h1: prego.textTheme.textXl.bold.copyWith(color: foreground),
    h2: prego.textTheme.textLg.bold.copyWith(color: foreground),
    h3: prego.textTheme.textMd.bold.copyWith(color: foreground),
    h4: prego.textTheme.textSm.bold.copyWith(color: foreground),
    h5: prego.textTheme.textSm.bold.copyWith(color: foreground),
    h6: prego.textTheme.textSm.bold.copyWith(color: foreground),
    em: body.copyWith(fontStyle: FontStyle.italic),
    strong: prego.textTheme.textSm.bold.copyWith(color: foreground),
    del: body.copyWith(decoration: TextDecoration.lineThrough),
    blockquote: body,
    checkbox: body,
    listBullet: body,
    tableHead: prego.textTheme.textSm.bold.copyWith(color: foreground),
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

/// Style sheet for the legal documents (terms, privacy) the backend serves as
/// markdown: a long-form reading layout with headings, numbered clauses and the
/// occasional inline link.
MarkdownStyleSheet buildLegalMarkdownStyleSheet({required PregoDesignSystem prego}) {
  final body = prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary);
  return MarkdownStyleSheet(
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
    codeblockDecoration: BoxDecoration(
      color: prego.colors.bgQuaternary,
      borderRadius: BorderRadius.circular(8),
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
