import "package:flutter/material.dart";

/// Theme-aware colors for diff rendering. Returns appropriate colors based on
/// the current [Brightness] (light or dark mode).
class DiffTheme {
  final Brightness brightness;

  const DiffTheme._({required this.brightness});

  factory DiffTheme.of(BuildContext context) => DiffTheme._(brightness: Theme.of(context).brightness);

  bool get _isDark => brightness == Brightness.dark;

  // ── Line backgrounds ──────────────────────────────────────────────────

  Color get addedBg => _isDark ? const Color(0xFF0D2818) : const Color(0xFFE6FFEC);

  Color get removedBg => _isDark ? const Color(0xFF2C0B0E) : const Color(0xFFFFEBE9);

  Color get contextBg => Colors.transparent;

  // ── Gutter backgrounds ────────────────────────────────────────────────

  Color get addedGutter => _isDark ? const Color(0xFF0F3A1E) : const Color(0xFFCCFFC9);

  Color get removedGutter => _isDark ? const Color(0xFF3D0F12) : const Color(0xFFFFDBD9);

  Color get contextGutter => _isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F8);

  // ── Hunk header ───────────────────────────────────────────────────────

  Color get hunkHeaderBg => _isDark ? const Color(0xFF161B22) : const Color(0xFFF1F8FF);

  Color get hunkHeaderBorder => _isDark ? const Color(0xFF30363D) : const Color(0xFFD1E5F0);

  Color get hunkHeaderText => _isDark ? const Color(0xFF8B949E) : const Color(0xFF57606A);

  // ── File header ───────────────────────────────────────────────────────

  Color get fileHeaderBg => _isDark ? const Color(0xFF161B22) : const Color(0xFFF6F8FA);

  Color get fileHeaderBorder => _isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE);

  // ── Text colors ───────────────────────────────────────────────────────

  Color get lineNumberText => _isDark ? const Color(0xFF484F58) : const Color(0xFF999999);

  Color get prefixText => _isDark ? const Color(0xFF8B949E) : const Color(0xFF666666);

  Color get codeText => _isDark ? const Color(0xFFE6EDF3) : const Color(0xFF24292F);

  Color get chevronColor => _isDark ? const Color(0xFF8B949E) : Colors.grey.shade600;
}
