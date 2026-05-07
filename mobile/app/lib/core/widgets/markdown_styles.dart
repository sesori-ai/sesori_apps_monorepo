import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_zyra/module_zyra.dart";

import "../di/injection.dart";

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
  required ZyraDesignSystem zyra,
  TextStyle? paragraphStyle,
}) {
  return MarkdownStyleSheet(
    p: paragraphStyle ?? zyra.textTheme.textSm.regular,
    codeblockDecoration: BoxDecoration(
      color: zyra.colors.bgQuaternary,
      borderRadius: BorderRadius.circular(8),
    ),
    code: TextStyle(
      fontFamily: "monospace",
      fontSize: 13,
      color: zyra.colors.textPrimary,
    ),
  );
}
