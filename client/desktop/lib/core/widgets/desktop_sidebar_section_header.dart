import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// A labelled sidebar section the user can fold. It shrinks away with the
/// sidebar, so the rail has no headers.
class const DesktopSidebarSectionHeader({
  super.key,
  required final String label,
  required final bool collapsed,
  required final double expansion,
  required final VoidCallback onToggle,
  required final Widget? action,
}) extends StatelessWidget {
  static const double _minWidth = 104;

  @override
  Widget build(BuildContext context) {
    // A hidden header must not stay in the focus order.
    if (expansion == 0) return const SizedBox.shrink();
    final prego = context.prego;
    final color = prego.colors.textSecondary;
    return ClipRect(
      child: Align(
        heightFactor: expansion,
        child: Opacity(
          opacity: expansion,
          // The collapsing rail gets narrower than a header's fixed parts.
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < _minWidth
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(PregoSpacing.md, PregoSpacing.sm, PregoSpacing.md, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            button: true,
                            expanded: !collapsed,
                            child: InkWell(
                              onTap: onToggle,
                              borderRadius: BorderRadius.circular(PregoRadius.md),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: PregoSpacing.sm,
                                  vertical: PregoSpacing.xs,
                                ),
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: prego.textTheme.textXs.bold.copyWith(color: color),
                                      ),
                                    ),
                                    const SizedBox(width: PregoSpacing.xs),
                                    Icon(
                                      collapsed ? TablerRegular.chevron_right : TablerRegular.chevron_down,
                                      size: 14,
                                      color: color,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        ?action,
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
