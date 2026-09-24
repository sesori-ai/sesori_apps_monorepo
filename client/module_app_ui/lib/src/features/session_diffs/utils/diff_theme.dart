import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// Diff colours, derived from Prego's status and neutral tokens so both themes
/// follow the palette.
class const DiffTheme._({required final PregoColors colors}) {
  factory of(BuildContext context) => DiffTheme._(colors: context.prego.colors);

  /// A changed line is tinted, not filled, so its text stays the loudest thing.
  static const double _lineTint = 0.1;

  // ── Lines ─────────────────────────────────────────────────────────────

  Color get addedBg => colors.fgSuccessPrimary.withValues(alpha: _lineTint);

  Color get removedBg => colors.fgErrorPrimary.withValues(alpha: _lineTint);

  Color get contextBg => Colors.transparent;

  /// The 2-point bar at a changed line's left edge.
  Color get addedBar => colors.fgSuccessPrimary;

  Color get removedBar => colors.fgErrorPrimary;

  // ── Hunk header ───────────────────────────────────────────────────────

  Color get hunkHeaderBg => colors.bgSecondary;

  Color get hunkHeaderBorder => colors.borderSecondary;

  Color get hunkHeaderText => colors.textTertiary;

  // ── File header ───────────────────────────────────────────────────────

  Color get fileHeaderBg => colors.bgSecondary;

  Color get fileHeaderBorder => colors.borderSecondary;

  // ── Text ──────────────────────────────────────────────────────────────

  Color get lineNumberText => colors.textQuaternary;

  Color get prefixText => colors.textTertiary;

  Color get codeText => colors.textPrimary;

  Color get chevronColor => colors.fgTertiary;
}
