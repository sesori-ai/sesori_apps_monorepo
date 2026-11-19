import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// A tappable answer card, shared by the question sheet and question pages.
/// A null [onTap] shows the card without answering taps, as a read-only page
/// does.
class const RequestChoiceTile({
  super.key,
  required final Color color,
  required final ShapeBorder shape,
  required final VoidCallback? onTap,
  required final Widget child,
  final Key? materialKey,
  final double bottomSpacing = 0,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tile = Material(
      key: materialKey,
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        mouseCursor: onTap == null ? MouseCursor.defer : WidgetStateMouseCursor.clickable,
        customBorder: shape,
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: child),
      ),
    );
    return bottomSpacing == 0
        ? tile
        : Padding(
            padding: EdgeInsetsDirectional.only(bottom: bottomSpacing),
            child: tile,
          );
  }
}

/// One option of a question: a radio for a single choice, a checkbox for a
/// multiple choice. [badge] sits beside the label, and [footer] below the
/// description, such as the option's image.
class const RequestOptionTile({
  super.key,
  required final String label,
  required final String? description,
  required final bool isMultiple,
  required final bool isSelected,
  required final VoidCallback? onTap,
  required final Widget? badge,
  required final Widget? footer,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return Semantics(
      selected: isSelected,
      child: RequestChoiceTile(
        bottomSpacing: 8,
        // bgSurface1 so the card reads as raised against the sheet's
        // bgSecondary surface (bgSecondary here would vanish into it).
        color: isSelected ? prego.colors.bgBrandPrimary : prego.colors.bgSurface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PregoRadius.xl)),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: footer == null ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Icon(
              isMultiple
                  ? (isSelected ? TablerSolid.square_rounded_check : TablerRegular.square_rounded)
                  : (isSelected ? TablerRegular.circle_dot : TablerRegular.circle),
              color: isSelected ? prego.colors.bgBrandSolid : prego.colors.borderPrimary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Wrap(
                    spacing: PregoSpacing.md,
                    runSpacing: PregoSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        label,
                        style: prego.textTheme.textSm.bold.copyWith(
                          fontWeight: .bold,
                        ),
                      ),
                      ?badge,
                    ],
                  ),
                  if (description case final description?) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: prego.textTheme.textXs.regular.copyWith(
                        color: prego.colors.textSecondary,
                      ),
                    ),
                  ],
                  if (footer case final footer?) ...[
                    const SizedBox(height: PregoSpacing.md),
                    footer,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
