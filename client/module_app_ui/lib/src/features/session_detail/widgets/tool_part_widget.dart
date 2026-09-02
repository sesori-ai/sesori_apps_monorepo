import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

import "../../../extensions/text_style_x.dart";
import "../../../l10n/app_localizations.dart";
import "../../../utils/copy_text_to_clipboard.dart";
import "attachment_collection_widget.dart";

class const ToolPartWidget({super.key, required final MessagePartTool part}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final state = part.state;
    final toolName = state.title ?? (part.tool.isEmpty ? loc.sessionDetailToolUnknown : part.tool);
    final status = state.status;
    final output = status == ToolStatus.completed ? state.output : null;
    final errorText = status == ToolStatus.error ? state.error : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: prego.colors.bgSecondary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: prego.colors.borderSecondary),
        ),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _statusIcon(status: status, prego: prego),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      toolName,
                      style: prego.textTheme.textSm.regular.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                  ),
                  Text(
                    _statusLabel(loc: loc, status: status),
                    style: prego.textTheme.textXs.medium.copyWith(
                      color: prego.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (output != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 8),
                child: _ToolOutputBlock(output: output),
              ),
            if (errorText != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 8),
                child: Text(
                  errorText,
                  style: prego.textTheme.textXs.regular.copyWith(
                    color: prego.colors.fgErrorPrimary,
                  ),
                  maxLines: 4,
                  overflow: .ellipsis,
                ),
              ),
            if (state.attachments.isNotEmpty)
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  prego.spacing.lg,
                  0,
                  prego.spacing.lg,
                  prego.spacing.md,
                ),
                child: AttachmentCollectionWidget(
                  sessionId: part.sessionID,
                  attachments: state.attachments,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon({required ToolStatus status, required PregoDesignSystem prego}) => switch (status) {
    ToolStatus.pending || ToolStatus.running => const SizedBox(
      width: 16,
      height: 16,
      child: PregoActivityIndicator(color: null),
    ),
    ToolStatus.completed => Icon(
      Icons.check_circle,
      size: 16,
      color: prego.colors.bgBrandSolid,
    ),
    ToolStatus.error => Icon(Icons.error, size: 16, color: prego.colors.fgErrorPrimary),
    ToolStatus.cancelled => Icon(
      Icons.cancel,
      size: 16,
      color: prego.colors.textSecondary,
    ),
    ToolStatus.unknown => Icon(
      Icons.circle_outlined,
      size: 16,
      color: prego.colors.borderPrimary,
    ),
  };

  String _statusLabel({required AppLocalizations loc, required ToolStatus status}) => switch (status) {
    ToolStatus.pending => loc.sessionDetailToolPending,
    ToolStatus.running => loc.sessionDetailToolRunning,
    ToolStatus.completed => loc.sessionDetailToolCompleted,
    ToolStatus.error => loc.sessionDetailToolError,
    ToolStatus.cancelled => loc.sessionDetailToolCancelled,
    ToolStatus.unknown => loc.sessionDetailToolUnknown,
  };
}

/// Tool output panel: collapsed to 8 lines by default with a one-tap copy
/// button, expandable to the full (previously hard-capped at 500 chars)
/// output. Kept collapsed by default so large outputs don't grow the list
/// or jank while streaming.
class const _ToolOutputBlock({required final String output}) extends StatefulWidget {
  @override
  State<_ToolOutputBlock> createState() => _ToolOutputBlockState();
}

class _ToolOutputBlockState() extends State<_ToolOutputBlock> {
  /// Collapsed line budget; mirrors the previous fixed `maxLines: 8`.
  static const _collapsedMaxLines = 8;

  bool _expanded = false;

  /// Horizontal space reserved at the text's trailing edge for the overlaid
  /// copy button, so wrapped text never runs under it and overflow is measured
  /// against the same width the text actually lays out in.
  static const _copyButtonReserve = 32.0;

  /// Inputs of the last overflow measurement. The parent list rebuilds every
  /// visible row on each streaming flush, so without this cache every rebuild
  /// would lay out a throwaway [TextPainter] per visible tool output.
  String? _measuredOutput;
  double? _measuredWidth;
  TextScaler? _measuredScaler;
  TextStyle? _measuredStyle;
  TextDirection? _measuredDirection;
  bool _isExpandable = false;

  bool _measureIsExpandable({
    required BuildContext context,
    required String output,
    required double textWidth,
    required TextStyle monoStyle,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    if (output == _measuredOutput &&
        textWidth == _measuredWidth &&
        textScaler == _measuredScaler &&
        monoStyle == _measuredStyle &&
        textDirection == _measuredDirection) {
      return _isExpandable;
    }
    final painter = TextPainter(
      text: TextSpan(text: output, style: monoStyle),
      maxLines: _collapsedMaxLines,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: textWidth);
    _measuredOutput = output;
    _measuredWidth = textWidth;
    _measuredScaler = textScaler;
    _measuredStyle = monoStyle;
    _measuredDirection = textDirection;
    _isExpandable = painter.didExceedMaxLines;
    painter.dispose();
    return _isExpandable;
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final output = widget.output;
    final monoStyle = prego.textTheme.textXs.regular.copyWith(fontSize: 11).monospace;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: prego.colors.bgQuaternary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Measure actual overflow against the collapsed budget at the real
          // text width (accounts for soft-wrapped long lines, not just
          // explicit newlines). maxLines bounds the layout cost.
          final textWidth = constraints.maxWidth - _copyButtonReserve;
          final isExpandable = _measureIsExpandable(
            context: context,
            output: output,
            textWidth: textWidth,
            monoStyle: monoStyle,
          );

          return Column(
            crossAxisAlignment: .start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Padding(
                      // Reserve trailing room for the overlaid copy button.
                      padding: const EdgeInsetsDirectional.only(end: _copyButtonReserve),
                      child: Text(
                        output,
                        style: monoStyle,
                        maxLines: _expanded ? null : _collapsedMaxLines,
                        overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: 0,
                    end: 0,
                    child: PregoCopyIconButton(
                      onCopy: () => copyTextToClipboard(text: output, operation: "tool output"),
                      tooltip: loc.sessionDetailCopy,
                      iconSize: 14,
                    ),
                  ),
                ],
              ),
              if (isExpandable)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(top: 4),
                    child: Text(
                      _expanded ? loc.sessionDetailShowLess : loc.sessionDetailShowMore,
                      style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.bgBrandSolid),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
