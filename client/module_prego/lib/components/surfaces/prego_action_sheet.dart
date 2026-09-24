import "dart:math" as math;

import "package:material_ui/material_ui.dart";

import "../../interactions/prego_interaction_scope.dart";
import "../../theme/prego_theme.dart";
import "prego_modal.dart";

/// A floating, content-sized sheet for a short decision flow.
///
/// Unlike the navigation bottom sheet, this has no header controls or grabber.
/// The caller owns route presentation and dismissal. Long content scrolls above
/// the action slot, keeping the decision controls visible. Compact viewports and
/// enlarged text use one scrollable flow so fixed actions cannot overflow, in
/// the sheet and the dialog alike.
///
/// Under a pointer [PregoInteractionScope] it is a [PregoModalWidth.request]
/// dialog instead, whose close button pops its route; present it with
/// [showPregoModalRoute].
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
    if (PregoInteractionScope.of(context) == PregoInteractionMode.pointer) {
      return PregoModalSurface(
        title: title,
        subtitle: null,
        onBack: null,
        // ignore: no_slop_linter/avoid_navigator_of, design module has no go_router dep; the caller's route owns this sheet
        onClose: () => Navigator.maybePop(context),
        width: PregoModalWidth.request,
        handleBottomSafeArea: true,
        topInset: topInset,
        child: _DecisionFlow(
          padding: EdgeInsetsDirectional.fromSTEB(prego.spacing.xl, 0, prego.spacing.xl, prego.spacing.xl),
          content: child,
          actions: actions,
        ),
      );
    }
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
            child: _DecisionFlow(
              // Figma's floating Sheet has a 26px top inset, not a spacing token.
              padding: EdgeInsetsDirectional.fromSTEB(prego.spacing.xl, 26, prego.spacing.xl, prego.spacing.xl),
              content: Column(
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
              actions: actions,
            ),
          ),
        ),
      ),
    );
  }
}

/// The content above the actions. Long content scrolls above them; a viewport
/// too short for that scrolls the whole flow, so the actions never overflow.
class const _DecisionFlow({
  required final EdgeInsetsGeometry padding,
  required final Widget content,
  required final Widget actions,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Below a comfortable 400px decision viewport, prefer a single
        // scrollable flow. Scale the breakpoint for accessibility text;
        // it is a layout policy, not a measurement of the action slot.
        final scrollAll = constraints.maxHeight < textScaler.scale(400);
        final body = Padding(
          padding: padding,
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
    );
  }
}
