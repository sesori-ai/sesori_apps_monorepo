import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../../extensions/build_context_x.dart";
import "model_effort_chip.dart";

/// The selected model's effort levels as one segmented strip, weakest on the
/// left and strongest on the right, exactly as the harness reports them. The
/// current level is filled; a tap on any level picks it.
class const ModelLevelStrip({
  super.key,

  /// Weakest first.
  required final List<SessionVariant> levels,

  /// The current level's id, or null when none of [levels] is current.
  required final String? selected,
  required final ValueChanged<SessionVariant> onPicked,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    final loc = context.loc;
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    final radius = BorderRadius.circular(PregoRadius.full);
    return Container(
      height: pointer ? 26 : 34,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: colors.bgSurface1, borderRadius: radius),
      child: Row(
        children: [
          for (final level in levels)
            Expanded(
              child: _Segment(
                label: effortLevelWord(level: level.id),
                semanticsLabel: loc.modelPickerLevel(effortLevelWord(level: level.id)),
                isSelected: level.id == selected,
                onTap: () => onPicked(level),
              ),
            ),
        ],
      ),
    );
  }
}

class const _Segment({
  required final String label,
  required final String semanticsLabel,
  required final bool isSelected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    final radius = BorderRadius.circular(PregoRadius.full);
    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? colors.bgBrandSolid : Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          mouseCursor: WidgetStateMouseCursor.clickable,
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              // Seven levels share a phone's width; a long word shrinks a
              // little rather than losing its end.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: prego.textTheme.textXs.medium.copyWith(
                    color: isSelected ? colors.textPrimaryOnBrand : colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
