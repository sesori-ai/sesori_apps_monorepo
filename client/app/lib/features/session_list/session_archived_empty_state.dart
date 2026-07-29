import "package:flutter/material.dart";
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

/// A stack of empty archive boxes seen edge-on, exported as PNGs from the Figma
/// "Group 12" node (`4429:7085`) and faded out towards its base.
///
/// Each theme ships its own artwork (plus @2x/@3x variants); the image matching
/// the active light/dark mode is chosen at build time, the way
/// `ConnectionGraphic` already does.
///
/// The exports are of the artwork alone, so the fade is applied here: Figma
/// hangs it under a 150pt top-to-bottom alpha ramp starting 57.83pt above the
/// artwork, which over the artwork's own box leaves the two stops below. The
/// illustration is meant to read as a faint suggestion, not a picture, so the
/// fade is not decoration that can be dropped.
class _ArchiveStackGlyph extends StatelessWidget {
  const _ArchiveStackGlyph({super.key});

  /// The Figma frame the artwork is drawn at, pinned explicitly rather than
  /// taken from the decoded asset — an unsized [Image] reports a *max
  /// intrinsic* height, which the hosting `SliverFillRemaining` would take for
  /// the real one and inflate the page's scroll extent with.
  ///
  /// The dark export is a few points shorter than the light one, which carries
  /// a drop shadow below its base. `BoxFit.contain` against the taller of the
  /// two, pinned to the top, lands both stacks in the same place.
  static const double _width = 210;
  static const double _height = 75;

  static const double _fadeTopOpacity = 0.61;
  static const double _fadeBottomOpacity = 0.11;

  static const String _dir = "assets/images/archived_sessions_empty";
  static const String _light = "$_dir/archive_stack-light.png";
  static const String _dark = "$_dir/archive_stack-dark.png";

  @override
  Widget build(BuildContext context) {
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
      child: Image.asset(
        context.isDarkMode ? _dark : _light,
        width: _width,
        height: _height,
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
