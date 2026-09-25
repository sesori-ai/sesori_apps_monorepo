import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../widgets/markdown_styles.dart";
import "../session_detail_presentation_scope.dart";

/// The quiet transcript row marking where the harness compacted its context.
/// Tapping it opens the carried-forward [summary]; without one it is inert.
class const CompactionPartWidget({super.key, required final String? summary}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final summary = this.summary;
    final color = prego.colors.textSecondary;
    return TextButton(
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
      child: Row(
        children: [
          Icon(TablerRegular.fold, size: PregoIconSize.sm, color: color),
          SizedBox(width: prego.spacing.md),
          Text(
            context.loc.sessionDetailContextCompacted,
            style: prego.textTheme.textSm.regular.copyWith(color: color),
          ),
        ],
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
