import "package:flutter/material.dart";
import "package:flutter_svg/flutter_svg.dart";

import "../../utils/lerp_utils.dart";

/// The available hero icon shapes.
///
/// Each value maps to an SVG asset in `assets/svgs/hero_icons/`.
/// These are the default profile icons assigned to new wallets
/// before the user sets a custom icon.
enum ZyraHeroIconType {
  icon1("hero_icon_1"),
  icon2("hero_icon_2"),
  icon3("hero_icon_3"),
  icon4("hero_icon_4"),
  icon5("hero_icon_5"),
  icon6("hero_icon_6"),
  icon7("hero_icon_7"),
  icon8("hero_icon_8"),
  icon9("hero_icon_9"),
  icon10("hero_icon_10"),
  ;

  const ZyraHeroIconType(this.id);

  /// Stable string identifier for database persistence.
  ///
  /// This value is **not** derived from [index] or [name] so it survives
  /// reordering, renaming, and code obfuscation. Once shipped, existing
  /// IDs must never change.
  final String id;

  /// Asset path for this hero icon.
  String get assetPath => "assets/svgs/hero_icons/$id.svg";

  /// Resolves a persisted [id] back to the corresponding enum value.
  ///
  /// Returns `null` if [id] does not match any known icon.
  static ZyraHeroIconType? fromId(String id) {
    for (final type in values) {
      if (type.id == id) return type;
    }
    return null;
  }
}

/// Displays a hero icon SVG with a dynamic gradient derived from [color].
///
/// The gradient direction is top-to-bottom:
/// - **Light mode**: white at the top, fading towards a lighter tint of [color]
///   at the bottom (never fully reaching the pure color).
/// - **Dark mode**: [color] at the top, fading towards a much darker shade
///   (towards black) at the bottom.
///
/// Usage:
/// ```dart
/// ZyraHeroIcon(
///   type: ZyraHeroIconType.icon1,
///   color: Colors.blue,
///   size: 48,
/// )
/// ```
class ZyraHeroIcon extends StatelessWidget {
  const ZyraHeroIcon({
    super.key,
    required this.type,
    required this.color,
    this.size,
  });

  /// Which hero icon shape to display.
  final ZyraHeroIconType type;

  /// Base color used to compute the gradient.
  final Color color;

  /// Width and height of the icon. When `null`, the SVG's intrinsic
  /// dimensions are used.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colorMapper = _HeroIconColorMapper.fromBrightness(
      color: color,
      brightness: brightness,
    );

    return SvgPicture.asset(
      type.assetPath,
      colorMapper: colorMapper,
      width: size,
      height: size,
    );
  }
}

/// Replaces the placeholder gradient colors in hero icon SVGs.
///
/// The original SVGs use a consistent `white -> #80B2FF` linear gradient.
/// This mapper substitutes those two stop-colors at parse time so the
/// gradient adapts to any base [Color] and respects light/dark mode.
///
/// Must be `@immutable` because `flutter_svg` uses it as part of a cache key.
@immutable
class _HeroIconColorMapper extends ColorMapper {
  const _HeroIconColorMapper({
    required this.gradientStart,
    required this.gradientEnd,
  });

  /// Computes gradient stops appropriate for the given [brightness].
  factory _HeroIconColorMapper.fromBrightness({
    required Color color,
    required Brightness brightness,
  }) {
    return switch (brightness) {
      // Light: white at top -> lighter tint of the color at bottom.
      // The lerp factor (0.5) keeps the end color softer than the pure
      // input, matching the Figma intent of "towards but not reaching"
      // the full color.
      Brightness.light => _HeroIconColorMapper(
        gradientStart: Colors.white,
        gradientEnd: lerpColorNonNull(Colors.white, color, 0.5),
      ),
      // Dark: full color at top -> much darker shade at bottom.
      Brightness.dark => _HeroIconColorMapper(
        gradientStart: color,
        gradientEnd: lerpColorNonNull(color, Colors.black, 0.7),
      ),
    };
  }

  /// Color for gradient position 0 (top of the icon).
  final Color gradientStart;

  /// Color for gradient position 1 (bottom of the icon).
  final Color gradientEnd;

  /// The original gradient-start color baked into the Figma SVGs.
  static const Color _originalGradientStart = Color(0xFFFFFFFF);

  /// The original gradient-end color baked into the Figma SVGs.
  static const Color _originalGradientEnd = Color(0xFF80B2FF);

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    if (color == _originalGradientEnd) return gradientEnd;
    if (color == _originalGradientStart) return gradientStart;
    return color;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HeroIconColorMapper && other.gradientStart == gradientStart && other.gradientEnd == gradientEnd;

  @override
  int get hashCode => Object.hash(gradientStart, gradientEnd);
}
