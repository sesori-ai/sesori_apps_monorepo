import "package:flutter/material.dart";
import "package:flutter_svg/flutter_svg.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/extensions/build_context_x.dart";

/// Empty state for the sessions list while the archived filter is on and the
/// project has nothing archived: a ghosted stack of archive boxes above the
/// line "No archived sessions".
///
/// Rendered inside a `SliverFillRemaining(hasScrollBody: false)`, so the
/// illustration is a fixed size — an unbounded one would inflate the scroll
/// extent.
class SessionArchivedEmptyState extends StatelessWidget {
  const SessionArchivedEmptyState({super.key});

  /// Gap between the illustration's box and the label, as drawn.
  static const double _labelGap = 33;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ExcludeSemantics(
            child: _ArchiveStackGlyph(key: Key("session-empty-archive")),
          ),
          const SizedBox(height: _labelGap),
          Text(
            context.loc.sessionListEmptyArchived,
            textAlign: TextAlign.center,
            style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// A stack of empty archive boxes seen edge-on, drawn from bundled artwork and
/// faded out towards its base.
///
/// The fade is Figma's: the artwork sits under a 150pt top-to-bottom alpha ramp
/// that starts 57.83pt above it, which over the artwork's own box leaves the
/// two stops below. The illustration is meant to read as a faint suggestion,
/// not a picture, so the fade is not decoration that can be dropped.
class _ArchiveStackGlyph extends StatelessWidget {
  const _ArchiveStackGlyph({super.key});

  /// The artwork's intrinsic size. Its drawn content stops just short of the
  /// bottom edge, where the export left room for a shadow.
  static const double _width = 210;
  static const double _height = 75;

  static const double _fadeTopOpacity = 0.61;
  static const double _fadeBottomOpacity = 0.11;

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;

    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: _fadeTopOpacity),
          Colors.white.withValues(alpha: _fadeBottomOpacity),
        ],
      ).createShader(bounds),
      child: SvgPicture.asset(
        "assets/images/archived_sessions_empty.svg",
        width: _width,
        height: _height,
        colorMapper: _ArchiveStackColorMapper(
          surface: colors.bgSurface4,
          background: colors.bgSurface1,
          icon: colors.textPrimary,
        ),
      ),
    );
  }
}

/// Carries the artwork's surfaces and glyph across to the current theme.
///
/// The export resolves its tokens to the light theme — white boxes shading
/// towards the page background, with a near-black archive glyph — which on a
/// dark surface would leave a white slab and an invisible glyph. Substituting
/// at parse time keeps light mode exactly as drawn and flips both with the
/// theme.
///
/// Must be `@immutable` because `flutter_svg` uses it as part of a cache key.
@immutable
class _ArchiveStackColorMapper extends ColorMapper {
  const _ArchiveStackColorMapper({required this.surface, required this.background, required this.icon});

  /// The light-theme token values baked into the exported artwork.
  static const Color _drawnSurface = Color(0xFFFFFFFF);
  static const Color _drawnBackground = Color(0xFFF0F0F0);
  static const Color _drawnIcon = Color(0xFF141414);

  final Color surface;
  final Color background;
  final Color icon;

  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) {
    if (color == _drawnSurface) return surface;
    if (color == _drawnBackground) return background;
    if (color == _drawnIcon) return icon;
    return color;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ArchiveStackColorMapper &&
          other.surface == surface &&
          other.background == background &&
          other.icon == icon;

  @override
  int get hashCode => Object.hash(surface, background, icon);
}
