import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart" show Harness;

import "../../icons/tabler_icons.g.dart";
import "../../icons/vespr_icons.g.dart";

class PregoBrandLogo extends StatelessWidget {
  const PregoBrandLogo({
    super.key,
    required this.pluginId,
    this.size = 20,
    required this.color,
  });

  final String pluginId;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Icon(
        _iconFor(pluginId),
        size: size,
        color: color,
      ),
    );
  }

  static IconData _iconFor(String pluginId) => switch (pluginId) {
    final id when id == Harness.opencode.name => VESPRSolid.opencode,
    final id when id == Harness.codex.name => VESPRSolid.codex,
    final id when id == Harness.cursor.name => VESPRSolid.cursor,
    _ => TablerRegular.plug,
  };

  /// What to call the harness this glyph stands for, for callers that have to
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
