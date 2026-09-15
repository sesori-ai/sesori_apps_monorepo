import "dart:math" as math;

import "package:material_ui/material_ui.dart";

import "../../theme/prego_theme.dart";

/// A floating, content-sized sheet for a short decision flow.
///
/// Unlike the navigation bottom sheet, this has no header controls or grabber.
/// The caller owns route presentation and dismissal. Long content scrolls above
/// the action slot, keeping the decision controls visible.
class const PregoActionSheet({
  super.key,
  required final String title,
  required final Widget child,
  required final Widget actions,

  /// Capture from the presenting context before a modal route removes it.
  required final double topInset,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final media = MediaQuery.of(context);
    final bottomInset = math.max(media.viewInsets.bottom, media.padding.bottom);
    final outerBottom = math.max(bottomInset, prego.spacing.xl);

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: prego.spacing.xl,
        end: prego.spacing.xl,
        bottom: outerBottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: math.max(0, media.size.height - topInset - prego.spacing.xl - outerBottom),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: prego.colors.bgSurface2,
            borderRadius: BorderRadius.circular(PregoRadius.x8l),
            boxShadow: prego.shadows.xl,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PregoRadius.x8l),
            child: Padding(
              // Figma's floating Sheet has a 26px top inset, not a spacing token.
              padding: EdgeInsetsDirectional.fromSTEB(prego.spacing.xl, 26, prego.spacing.xl, prego.spacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(title, style: prego.textTheme.textMd.medium),
                          ),
                          SizedBox(height: prego.spacing.xl),
                          child,
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: prego.spacing.xl),
                  actions,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
