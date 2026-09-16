import "dart:math" as math;

import "package:material_ui/material_ui.dart";

import "../../theme/prego_theme.dart";

/// A floating, content-sized sheet for a short decision flow.
///
/// Unlike the navigation bottom sheet, this has no header controls or grabber.
/// The caller owns route presentation and dismissal. Long content scrolls above
/// the action slot, keeping the decision controls visible. Compact viewports and
/// enlarged text use one scrollable flow so fixed actions cannot overflow.
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
    final bottomInset = media.viewInsets.bottom > 0 ? media.viewInsets.bottom : media.padding.bottom;
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Below a comfortable 400px decision viewport, prefer a single
                // scrollable flow. Scale the breakpoint for accessibility text;
                // it is a layout policy, not a measurement of the action slot.
                final scrollAll = constraints.maxHeight < media.textScaler.scale(400);
                final content = Column(
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
                );
                final body = Padding(
                  // Figma's floating Sheet has a 26px top inset, not a spacing token.
                  padding: EdgeInsetsDirectional.fromSTEB(prego.spacing.xl, 26, prego.spacing.xl, prego.spacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (scrollAll) content else Flexible(child: SingleChildScrollView(child: content)),
                      SizedBox(height: prego.spacing.xl),
                      actions,
                    ],
                  ),
                );
                return scrollAll ? SingleChildScrollView(child: body) : body;
              },
            ),
          ),
        ),
      ),
    );
  }
}
