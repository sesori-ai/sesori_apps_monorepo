import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../platform/external_link_opener.dart";
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
      builder: (modalContext) => _CompactionSummary(
        summary: summary,
        openExternalLink: openExternalLink,
        entry: ModalRoute.of(modalContext)?.animation,
      ),
    );
  }
}

/// The summary as Markdown, built once the modal has finished opening, with a
/// spinner in its place until then. A summary can run to tens of kilobytes, and
/// laying it out in the modal's first frame held that frame long enough to
/// swallow the tap's ripple and skip the entry transition.
class const _CompactionSummary({
  required final String summary,
  required final ExternalLinkOpener openExternalLink,

  /// The modal route's entry transition.
  required final Animation<double>? entry,
}) extends StatefulWidget {
  @override
  State<_CompactionSummary> createState() => _CompactionSummaryState();
}

class _CompactionSummaryState() extends State<_CompactionSummary> {
  static const _loadingHeight = 220.0;

  /// The entry transition while it still runs; null once the summary builds.
  Animation<double>? _opening;

  @override
  void initState() {
    super.initState();
    // Only a transition running forward completes later: a modal opened
    // without one, under reduced motion, is already open.
    final entry = widget.entry;
    if (entry != null && entry.status == AnimationStatus.forward) {
      _opening = entry..addStatusListener(_onEntryStatus);
    }
  }

  void _onEntryStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _opening?.removeStatusListener(_onEntryStatus);
    setState(() => _opening = null);
  }

  @override
  void dispose() {
    _opening?.removeStatusListener(_onEntryStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_opening != null) {
      return const SizedBox(
        height: _loadingHeight,
        child: Center(child: PregoActivityIndicator(color: null)),
      );
    }
    final prego = context.prego;
    return PregoReadableSelectionArea(
      child: MarkdownBody(
        data: widget.summary,
        selectable: false,
        blockSyntaxes: sessionMarkdownBlockSyntaxes,
        imageBuilder: (uri, title, alt) => MarkdownMessageImage(uri: uri, semanticLabel: alt),
        onTapLink: buildMarkdownLinkTapHandler(openExternalLink: widget.openExternalLink),
        styleSheet: buildSessionMarkdownStyleSheet(
          prego: prego,
          paragraphStyle: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
        ),
      ),
    );
  }
}
