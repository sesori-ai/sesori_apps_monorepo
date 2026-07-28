import "package:flutter/material.dart";
import "package:flutter_svg/flutter_svg.dart";
import "package:sesori_shared/sesori_shared.dart" show Harness;

import "../../icons/tabler_icons.g.dart";
import "../../theme/prego_theme.dart";

/// The mark of the harness a session, project or setting belongs to.
///
/// Each supported harness has its own artwork, so a screen mixing backends
/// tells them apart at a glance. A harness this build has no artwork for — a
/// newer bridge can advertise one — falls back to a plug drawn in [color].
///
/// The mark is decorative. Callers that lean on it to identify the harness
/// must say so in words themselves; [displayNameFor] gives them the name.
class PregoBrandLogo extends StatelessWidget {
  const PregoBrandLogo({
    super.key,
    required this.pluginId,
    this.size = 20,
    required this.color,
  });

  final String pluginId;
  final double size;

  /// Tints the fallback plug. The brand marks ignore it: they are drawn in
  /// their own colours, which is the point of them.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final asset = _assetFor(pluginId);
    if (asset == null) {
      return ExcludeSemantics(child: Icon(TablerRegular.plug, size: size, color: color));
    }

    final colors = context.prego.colors;
    return ExcludeSemantics(
      child: SvgPicture.asset(
        asset,
        package: "theme_prego",
        width: size,
        height: size,
        colorMapper: _BrandColorMapper(primary: colors.textPrimary, secondary: colors.textSecondary),
      ),
    );
  }

  static String? _assetFor(String pluginId) => switch (pluginId) {
    final id when id == Harness.opencode.name => "assets/svgs/brands/opencode.svg",
    final id when id == Harness.codex.name => "assets/svgs/brands/codex.svg",
    final id when id == Harness.cursor.name => "assets/svgs/brands/cursor.svg",
    _ => null,
  };

  /// What to call the harness this mark stands for, for callers that have to
  /// say in words what the logo says by sight.
  ///
  /// Brand names are proper nouns, so they are not translated. A newer bridge
  /// can advertise a harness this build has never heard of; its id is then the
  /// truest name available, and speaking it beats saying nothing.
  static String displayNameFor(String pluginId) => switch (pluginId) {
    final id when id == Harness.opencode.name => "OpenCode",
    final id when id == Harness.codex.name => "Codex",
    final id when id == Harness.cursor.name => "Cursor",
    _ => pluginId,
  };
}

/// Carries the marks that are drawn in text colours across to the current
/// theme.
///
/// The artwork comes out of Figma with its greys resolved to the light theme's
/// `text-primary` and `text-secondary`, which on a dark surface would leave
/// those marks all but invisible. Substituting at parse time keeps light mode
/// exactly as drawn and flips the greys with the theme.
///
/// Only those two are touched. A mark drawn in its own brand colours — Codex's
/// gradient — is the whole reason for shipping artwork rather than glyphs, and
/// white is load-bearing in the masks the exports use.
///
/// Must be `@immutable` because `flutter_svg` uses it as part of a cache key.
@immutable
class _BrandColorMapper extends ColorMapper {
  const _BrandColorMapper({required this.primary, required this.secondary});

  /// The light-theme token values baked into the exported artwork.
  static const Color _drawnPrimary = Color(0xFF141414);
  static const Color _drawnSecondary = Color(0xFF474747);

  final Color primary;
  final Color secondary;

  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) {
    if (color == _drawnPrimary) return primary;
    if (color == _drawnSecondary) return secondary;
    return color;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _BrandColorMapper && other.primary == primary && other.secondary == secondary;

  @override
  int get hashCode => Object.hash(primary, secondary);
}
