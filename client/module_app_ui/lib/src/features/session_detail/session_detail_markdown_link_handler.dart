import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../widgets/markdown_styles.dart";
import "file_preview/file_preview_screen.dart";
import "session_detail_presentation_scope.dart";

/// Creates a Markdown link handler that resolves product policy only when a
/// link is actually activated. Rendering transcript Markdown does not itself
/// exercise a platform capability.
///
/// Web and mail links follow the outbound-link policy. Any other link that
/// reads as a file reference opens in this computer's default app or in the
/// in-app preview; a link that does not is ignored.
MarkdownTapLinkCallback buildSessionDetailMarkdownLinkTapHandler({required BuildContext context}) {
  // ignore: no_slop_linter/prefer_required_named_parameters, callback signature is defined by MarkdownBody.onTapLink
  return (String text, String? href, String title) {
    if (href == null) return;
    if (_isWebOrMailLink(href: href)) {
      buildMarkdownLinkTapHandler(
        openExternalLink: SessionDetailPresentationScope.read(context).openExternalLink,
      )(text, href, title);
      return;
    }
    unawaited(_openFileReference(context: context, raw: href));
  };
}

bool _isWebOrMailLink({required String href}) {
  final scheme = Uri.tryParse(href)?.scheme.toLowerCase();
  return scheme == "http" || scheme == "https" || scheme == "mailto";
}

Future<void> _openFileReference({required BuildContext context, required String raw}) async {
  final reference = await context.read<SessionDetailCubit>().openFileReference(raw: raw);
  if (reference == null || !context.mounted) return;
  await showFilePreview(context: context, reference: reference);
}
