import "package:flutter/material.dart";

import "zyra_colors.g.dart";

/// Shadow tokens matching Figma shadow effect styles.
///
/// Each shadow level is composed of one or more [BoxShadow] layers.
/// Shadow colors are sourced from [ZyraColors] tokens, enabling
/// proper light/dark mode support.
///
/// Access via `context.zyra.shadows`:
/// ```dart
/// Container(
///   decoration: BoxDecoration(
///     boxShadow: context.zyra.shadows.sm,
///   ),
/// )
/// ```
@immutable
final class ZyraShadows {
  const ZyraShadows({required this.colors});

  final ZyraColors colors;

  /// Figma: shadow-xs
  /// Single layer: offset(0, 1), blur 2, spread 0
  List<BoxShadow> get xs => [
    BoxShadow(
      color: colors.shadowXs,
      offset: const Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  /// Figma: shadow-sm
  /// Two layers composited together.
  List<BoxShadow> get sm => [
    BoxShadow(
      color: colors.shadowSm01,
      offset: const Offset(0, 1),
      blurRadius: 3,
    ),
    BoxShadow(
      color: colors.shadowSm02,
      offset: const Offset(0, 1),
      blurRadius: 2,
      spreadRadius: -1,
    ),
  ];

  /// Figma: shadow-md
  /// Two layers composited together.
  List<BoxShadow> get md => [
    BoxShadow(
      color: colors.shadowMd01,
      offset: const Offset(0, 4),
      blurRadius: 8,
      spreadRadius: -2,
    ),
    BoxShadow(
      color: colors.shadowMd02,
      offset: const Offset(0, 2),
      blurRadius: 4,
      spreadRadius: -2,
    ),
  ];

  /// Figma: shadow-lg
  /// Two layers composited together.
  List<BoxShadow> get lg => [
    BoxShadow(
      color: colors.shadowLg01,
      offset: const Offset(0, 12),
      blurRadius: 16,
      spreadRadius: -4,
    ),
    BoxShadow(
      color: colors.shadowLg02,
      offset: const Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -2,
    ),
  ];

  /// Figma: shadow-xl
  /// Two layers composited together.
  List<BoxShadow> get xl => [
    BoxShadow(
      color: colors.shadowXl01,
      offset: const Offset(0, 20),
      blurRadius: 24,
      spreadRadius: -4,
    ),
    BoxShadow(
      color: colors.shadowXl02,
      offset: const Offset(0, 8),
      blurRadius: 8,
      spreadRadius: -4,
    ),
  ];

  /// Figma: shadow-2xl
  /// Single layer: offset(0, 24), blur 48, spread -12
  List<BoxShadow> get xxl => [
    BoxShadow(
      color: colors.shadow2xl01,
      offset: const Offset(0, 24),
      blurRadius: 48,
      spreadRadius: -12,
    ),
  ];

  /// Figma: shadow-3xl
  /// Single layer: offset(0, 32), blur 64, spread -12
  List<BoxShadow> get xxxl => [
    BoxShadow(
      color: colors.shadow3xl01,
      offset: const Offset(0, 32),
      blurRadius: 64,
      spreadRadius: -12,
    ),
  ];
}
