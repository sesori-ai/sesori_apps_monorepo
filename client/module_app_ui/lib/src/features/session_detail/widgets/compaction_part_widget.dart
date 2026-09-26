import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../widgets/markdown_styles.dart";
import "../session_detail_presentation_scope.dart";
import "text_part_widget.dart";
import "transcript_live_row.dart";

/// The quiet transcript row marking where the harness compacted its context.
/// Tapping it opens the carried-forward [summary]; without one it is inert.
class const CompactionPartWidget({super.key, required final String? summary}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    final color = context.prego.colors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextButton(
        onPressed: summary == null ? null : () => _showSummary(context: context, summary: summary),
        style: TextButton.styleFrom(
          foregroundColor: color,
          disabledForegroundColor: color,
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: AlignmentDirectional.centerStart,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PregoRadius.xs)),
        ),
        child: TranscriptStepRow(
          leading: Icon(TablerRegular.fold, size: PregoIconSize.sm, color: color),
          label: context.loc.sessionDetailContextCompacted,
          detail: null,
          live: false,
          color: null,
          below: null,
        ),
      ),
    );
  }

  static Future<void> _showSummary({required BuildContext context, required String summary}) {
    final openExternalLink = SessionDetailPresentationScope.read(context).openExternalLink;
    return showPregoModal<void>(
      context: context,
      title: context.loc.sessionDetailCompactionSummaryTitle,
      width: PregoModalWidth.reading,
      builder: (modalContext) {
        final prego = modalContext.prego;
        return PregoReadableSelectionArea(
          child: MarkdownBody(
            data: summary,
            selectable: false,
            blockSyntaxes: sessionMarkdownBlockSyntaxes,
            imageBuilder: (uri, title, alt) => MarkdownMessageImage(uri: uri, semanticLabel: alt),
            onTapLink: buildMarkdownLinkTapHandler(openExternalLink: openExternalLink),
            styleSheet: buildSessionMarkdownStyleSheet(
              prego: prego,
              paragraphStyle: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
            ),
          ),
        );
      },
    );
  }
}
