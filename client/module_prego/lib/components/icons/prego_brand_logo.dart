import "package:flutter/material.dart";

import "../../icons/tabler_icons.g.dart";
import "../../icons/vespr_icons.g.dart";

class PregoBrandLogo extends StatelessWidget {
  const PregoBrandLogo({
    super.key,
    required this.brandLogoKey,
    this.size = 20,
    this.color,
  });

  final String? brandLogoKey;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Icon(
        _iconFor(brandLogoKey),
        size: size,
        color: color,
      ),
    );
  }

  static IconData _iconFor(String? brandLogoKey) => switch (brandLogoKey) {
    "opencode" => VESPRSolid.opencode,
    "codex" => VESPRSolid.codex,
    "cursor" => VESPRSolid.cursor,
    null || _ => TablerRegular.plug,
  };
}
