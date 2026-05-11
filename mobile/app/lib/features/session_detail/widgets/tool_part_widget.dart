import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";
import "../../../core/extensions/build_context_x.dart";
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
                      color: zyra.colors.borderPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (output != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: zyra.colors.bgQuaternary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _truncateOutput(output),
                    style: zyra.textTheme.textXs.regular.copyWith(
                      fontFamily: "monospace",
                      fontSize: 11,
                    ),
                    maxLines: 8,
                    overflow: .ellipsis,
                  ),
                ),
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

  String _truncateOutput(String output) {
    if (output.length <= 500) return output;
    return "${output.substring(0, 500)}...";
  }
}
