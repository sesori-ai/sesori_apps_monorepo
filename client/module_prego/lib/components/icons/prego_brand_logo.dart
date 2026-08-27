import "package:flutter_svg/flutter_svg.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart" show Harness;

import "../../icons/tabler_icons.g.dart";
import "../../theme/prego_theme.dart";

/// The mark of the harness a session, project or setting belongs to.
///
/// Each supported harness has its own artwork, so a screen mixing backends
/// tells them apart at a glance. Theme-specific exports follow the current
/// brightness; theme-independent marks keep their official brand colours. A
/// harness this build has no artwork for — a newer bridge can advertise one
/// — falls back to a plug drawn in [color].
///
/// The mark is decorative. Callers that lean on it to identify the harness
/// must say so in words themselves; [displayNameFor] gives them the name.
class const PregoBrandLogo({
  super.key,
  required final String pluginId,
  final double size = 20,

  /// Tints the fallback plug. The brand marks ignore it: they are drawn in
  /// their own colours, which is the point of them.
  required final Color? color,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final asset = _assetFor(pluginId, brightness: context.prego.colors.brightness);
    if (asset == null) {
      return ExcludeSemantics(
        child: Icon(TablerRegular.plug, size: size, color: color),
      );
    }

    return ExcludeSemantics(
      child: SvgPicture.asset(asset, package: "theme_prego", width: size, height: size),
    );
  }

  static String? _assetFor(String pluginId, {required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    return switch (pluginId) {
      final id when id == Harness.opencode.name =>
        isDark ? "assets/svgs/brands/opencode_dark.svg" : "assets/svgs/brands/opencode_light.svg",
      final id when id == Harness.codex.name =>
        isDark ? "assets/svgs/brands/codex_dark.svg" : "assets/svgs/brands/codex_light.svg",
      final id when id == Harness.cursor.name =>
        isDark ? "assets/svgs/brands/cursor_dark.svg" : "assets/svgs/brands/cursor_light.svg",
      final id when id == Harness.claude.name =>
        isDark ? "assets/svgs/brands/claude_dark.svg" : "assets/svgs/brands/claude_light.svg",
      final id when id == Harness.hermes.name =>
        isDark ? "assets/svgs/brands/hermes_dark.svg" : "assets/svgs/brands/hermes_light.svg",
      final id when id == Harness.pi.name =>
        isDark ? "assets/svgs/brands/pi_dark.svg" : "assets/svgs/brands/pi_light.svg",
      final id when id == Harness.omp.name => "assets/svgs/brands/omp.svg",
      final id when id == Harness.deepseek.name => "assets/svgs/brands/deepseek.svg",
      _ => null,
    };
  }

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
    final id when id == Harness.claude.name => "Claude Code",
    final id when id == Harness.hermes.name => "Hermes Agent",
    final id when id == Harness.pi.name => "Pi",
    final id when id == Harness.omp.name => "Oh My Pi",
    final id when id == Harness.deepseek.name => "DeepSeek",
    _ => pluginId,
  };
}
