import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/extensions/text_style_x.dart";
import "../../../core/widgets/copy_icon_button.dart";
import "../../../l10n/app_localizations.dart";

class ToolPartWidget extends StatelessWidget {
  final MessagePart part;

  const ToolPartWidget({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final state = part.state;
    final toolName = part.state?.title ?? part.tool ?? loc.sessionDetailToolUnknown;
    final status = state?.status ?? ToolStatus.pending;
    final output = status == ToolStatus.completed ? state?.output : null;
    final errorText = status == ToolStatus.error ? state?.error : null;

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
          ],
        ),
      ),
    );
  }

  Widget _statusIcon({required ToolStatus status, required PregoDesignSystem prego}) => switch (status) {
    ToolStatus.pending || ToolStatus.running => SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: prego.colors.bgBrandSolid,
      ),
    ),
    ToolStatus.completed => Icon(
      Icons.check_circle,
      size: 16,
      color: prego.colors.bgBrandSolid,
    ),
    ToolStatus.error => Icon(Icons.error, size: 16, color: prego.colors.fgErrorPrimary),
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
    ToolStatus.unknown => loc.sessionDetailToolUnknown,
  };
}

/// Tool output panel: collapsed to 8 lines by default with a one-tap copy
/// button, expandable to the full (previously hard-capped at 500 chars)
/// output. Kept collapsed by default so large outputs don't grow the list
/// or jank while streaming.
class _ToolOutputBlock extends StatefulWidget {
  final String output;

  const _ToolOutputBlock({required this.output});

  @override
  State<_ToolOutputBlock> createState() => _ToolOutputBlockState();
}

class _ToolOutputBlockState extends State<_ToolOutputBlock> {
  /// Collapsed line budget; mirrors the previous fixed `maxLines: 8`.
  static const _collapsedMaxLines = 8;

  bool _expanded = false;

  /// Horizontal space reserved at the text's trailing edge for the overlaid
  /// copy button, so wrapped text never runs under it and overflow is measured
  /// against the same width the text actually lays out in.
  static const _copyButtonReserve = 32.0;

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
          final painter = TextPainter(
            text: TextSpan(text: output, style: monoStyle),
            maxLines: _collapsedMaxLines,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: textWidth);
          final isExpandable = painter.didExceedMaxLines;

          return Column(
            crossAxisAlignment: .start,
            children: [
              Stack(
                children: [
                  Padding(
                    // Reserve trailing room for the overlaid copy button.
                    padding: const EdgeInsetsDirectional.only(end: _copyButtonReserve),
                    child: Text(
                      output,
                      style: monoStyle,
                      maxLines: _expanded ? null : _collapsedMaxLines,
                      overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
                    ),
                  ),
                  PositionedDirectional(
                    top: 0,
                    end: 0,
                    child: CopyIconButton(text: output, tooltip: loc.sessionDetailCopy, iconSize: 14),
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
