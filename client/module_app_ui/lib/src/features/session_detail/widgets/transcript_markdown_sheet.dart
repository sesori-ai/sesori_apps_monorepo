import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../widgets/defer_until_route_open.dart";
import "../../../widgets/markdown_styles.dart";
import "../session_detail_presentation_scope.dart";
import "text_part_widget.dart";

/// Opens [markdown] that a transcript row stands for, such as a compaction's
/// summary, in a reading sheet on touch or a dialog under a pointer.
Future<void> showTranscriptMarkdownSheet({
  required BuildContext context,
  required String title,
  required String markdown,
}) {
  final scope = SessionDetailPresentationScope.read(context);
  return showPregoModal<void>(
    context: context,
    title: title,
    width: PregoModalWidth.reading,
    builder: (modalContext) {
      final prego = modalContext.prego;
      // The sheet's route does not inherit the page's scope, which its images
      // and their viewer read.
      return scope.around(
        openSession: scope.openSession,
        child: DeferUntilRouteOpen(
          contentLength: markdown.length,
          child: PregoReadableSelectionArea(
            child: MarkdownBody(
              data: markdown,
              selectable: false,
              blockSyntaxes: sessionMarkdownBlockSyntaxes,
              imageBuilder: (uri, title, alt) => MarkdownMessageImage(uri: uri, semanticLabel: alt),
              onTapLink: buildMarkdownLinkTapHandler(openExternalLink: scope.openExternalLink),
              styleSheet: buildSessionMarkdownStyleSheet(
                prego: prego,
                paragraphStyle: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
              ),
            ),
          ),
        ),
      );
    },
  );
}
