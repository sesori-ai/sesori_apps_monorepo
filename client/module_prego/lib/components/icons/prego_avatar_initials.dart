import "package:material_ui/material_ui.dart";

import "../../icons/tabler_icons.g.dart";
import "../../theme/prego_theme.dart";

/// Compact identity mark with stable colour and up to two grapheme initials.
class const PregoAvatarInitials({
  super.key,
  required final String label,
  final double size = 28,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final words = label.trim().split(RegExp(r"\s+")).where((word) => word.isNotEmpty).toList();
    final initials = words.isEmpty
        ? null
        : words.length == 1
        ? words.first.characters.take(2).toString().toUpperCase()
        : "${words.first.characters.first}${words[1].characters.first}".toUpperCase();
    final colors = context.prego.colors;
    final palette = [
      colors.textBrandPrimary,
      colors.textSuccessPrimary,
      colors.textWarningPrimary,
      colors.textSecondary,
    ];
    final hash = label.runes.fold(0, (hash, rune) => (hash * 31 + rune) & 0x7fffffff);
    final color = palette[hash % palette.length];

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(PregoRadius.md),
        ),
        child: initials == null
            ? Icon(TablerRegular.folder, size: size / 2, color: color)
            : Text(
                initials,
                style: context.prego.textTheme.textXs.medium.copyWith(color: color, package: "theme_prego"),
                maxLines: 1,
              ),
      ),
    );
  }
}
