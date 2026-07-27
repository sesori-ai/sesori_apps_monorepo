import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart" show Harness;

import "../../icons/tabler_icons.g.dart";
import "../../icons/vespr_icons.g.dart";

class PregoBrandLogo extends StatelessWidget {
  const PregoBrandLogo({
    super.key,
    required this.pluginId,
    this.size = 20,
    this.color,
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
}
