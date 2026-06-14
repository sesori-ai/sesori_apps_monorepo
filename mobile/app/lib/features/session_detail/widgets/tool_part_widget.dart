import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/extensions/text_style_x.dart";
import "../../../core/widgets/copy_icon_button.dart";
import "../../../l10n/app_localizations.dart";

class ToolPartWidget extends StatelessWidget {
  final MessagePart part;

  const ToolPartWidget({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final loc = context.loc;
    final state = part.state;
    final toolName = part.state?.title ?? part.tool ?? loc.sessionDetailToolUnknown;
    final status = state?.status ?? "pending";
    final output = status == "completed" ? state?.output : null;
    final errorText = status == "error" ? state?.error : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: zyra.colors.bgSecondary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: zyra.colors.borderSecondary),
        ),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _statusIcon(status: status, zyra: zyra),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      toolName,
                      style: zyra.textTheme.textSm.regular.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                  ),
                  Text(
                    _statusLabel(loc: loc, status: status),
                    style: zyra.textTheme.textXs.medium.copyWith(
                      color: zyra.colors.textSecondary,
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
                    style: zyra.textTheme.textXs.regular.copyWith(
                      color: zyra.colors.fgErrorPrimary,
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

  Widget _statusIcon({required String status, required ZyraDesignSystem zyra}) => switch (status) {
    "pending" || "running" => SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: zyra.colors.bgBrandSolid,
      ),
    ),
    "completed" => Icon(
      Icons.check_circle,
      size: 16,
      color: zyra.colors.bgBrandSolid,
    ),
    "error" => Icon(Icons.error, size: 16, color: zyra.colors.fgErrorPrimary),
    _ => Icon(
      Icons.circle_outlined,
      size: 16,
      color: zyra.colors.borderPrimary,
    ),
  };

  String _statusLabel({required AppLocalizations loc, required String status}) => switch (status) {
    "pending" => loc.sessionDetailToolPending,
    "running" => loc.sessionDetailToolRunning,
    "completed" => loc.sessionDetailToolCompleted,
    "error" => loc.sessionDetailToolError,
    _ => status,
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

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final loc = context.loc;
    final output = widget.output;
    // Show the expand toggle only when content plausibly overflows the
    // collapsed budget: more than 8 lines, or one long wrapping line.
    final isExpandable = output.length > 500 || "\n".allMatches(output).length >= _collapsedMaxLines;
    final monoStyle = zyra.textTheme.textXs.regular.copyWith(fontSize: 11).monospace;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: zyra.colors.bgQuaternary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            crossAxisAlignment: .start,
            children: [
              Expanded(
                child: Text(
                  output,
                  style: monoStyle,
                  maxLines: _expanded ? null : _collapsedMaxLines,
                  overflow: _expanded ? TextOverflow.clip : TextOverflow.ellipsis,
                ),
              ),
              CopyIconButton(text: output, tooltip: loc.sessionDetailCopy, iconSize: 14),
            ],
          ),
          if (isExpandable)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _expanded ? loc.sessionDetailShowLess : loc.sessionDetailShowMore,
                  style: zyra.textTheme.textXs.medium.copyWith(color: zyra.colors.bgBrandSolid),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
