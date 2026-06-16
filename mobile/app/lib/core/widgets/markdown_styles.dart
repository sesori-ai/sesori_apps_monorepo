import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../di/injection.dart";
import "../extensions/text_style_x.dart";
import "code_block.dart";

/// Shared [MarkdownBody.onTapLink] handler that opens URLs in the system
/// browser via the DI-registered [UrlLauncher].
// ignore: no_slop_linter/prefer_required_named_parameters, callback signature is defined by MarkdownBody.onTapLink
void handleMarkdownLinkTap(String text, String? href, String title) {
  if (href == null) return;
  final uri = Uri.tryParse(href);
  if (uri == null) return;
  getIt<UrlLauncher>().launch(uri);
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
