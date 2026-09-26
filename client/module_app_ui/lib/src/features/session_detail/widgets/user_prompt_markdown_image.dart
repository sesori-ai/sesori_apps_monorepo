import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../session_detail_markdown_link_handler.dart";
import "text_part_widget.dart" show MarkdownMessageImage;

/// How a Markdown image inside the user's own prompt is rendered, wherever that
/// prompt is shown: in the transcript's bubble and in the prompt pinned over
/// the transcript's top edge.
///
/// A remote image is a button that opens the URL, never an inline fetch: a
/// prompt can name any third-party host, and reading or scrolling the
/// transcript must not tell that host the reader is there. An image that
/// carries its own bytes, or an asset, renders inline.
///
/// Pass `interactive: false` where the prompt is a preview whose own tap does
/// something else, as the pinned prompt's is: a control that looks pressable
/// and opens nothing is worse than naming the image in plain text.
Widget buildUserPromptMarkdownImage({
  required BuildContext context,
  required Uri uri,
  required String? semanticLabel,
  required bool interactive,
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
  if (!interactive) return _RemoteImageMention(label: label);

  final handleLink = buildSessionDetailMarkdownLinkTapHandler(context: context);
  return TextButton.icon(
    onPressed: () => handleLink(label, uri.toString(), ""),
    icon: const Icon(TablerRegular.photo, size: PregoIconSize.sm),
    label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    style: TextButton.styleFrom(
      foregroundColor: prego.colors.textPrimary,
      backgroundColor: prego.colors.textPrimary.withValues(alpha: 0.08),
      minimumSize: const Size(44, 44),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: PregoSpacing.lg,
        vertical: PregoSpacing.md,
      ),
      textStyle: prego.textTheme.textSm.medium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PregoRadius.md),
        side: BorderSide(
          color: prego.colors.textPrimary.withValues(alpha: 0.24),
        ),
      ),
    ),
  );
}

/// Names the image the prompt links to, with no surface and nothing to press.
class const _RemoteImageMention({required final String label}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final style = prego.textTheme.textSm.medium.copyWith(color: prego.colors.textSecondary);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(TablerRegular.photo, size: PregoIconSize.sm, color: prego.colors.textSecondary),
        const SizedBox(width: PregoSpacing.xs),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ),
      ],
    );
  }
}
