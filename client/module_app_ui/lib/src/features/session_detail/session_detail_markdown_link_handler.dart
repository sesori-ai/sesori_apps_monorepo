import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";

import "../../widgets/markdown_styles.dart";
import "session_detail_presentation_scope.dart";

/// Creates a Markdown link handler that resolves product policy only when a
/// link is actually activated. Rendering transcript Markdown does not itself
/// exercise a platform capability.
MarkdownTapLinkCallback buildSessionDetailMarkdownLinkTapHandler({required BuildContext context}) {
  // ignore: no_slop_linter/prefer_required_named_parameters, callback signature is defined by MarkdownBody.onTapLink
  return (String text, String? href, String title) {
    buildMarkdownLinkTapHandler(
      openExternalLink: SessionDetailPresentationScope.read(context).openExternalLink,
    )(text, href, title);
  };
}
