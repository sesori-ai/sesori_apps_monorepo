import "package:material_ui/material_ui.dart";

/// Makes a button one screen reader node: its name, button flag, enabled state,
/// tap and focus together.
///
/// A [Tooltip]'s or a bare [Semantics]' words land on whichever ancestor takes
/// them, while the tap inside a button can sit on a separate unnamed node.
class const PregoButtonSemantics({
  super.key,

  /// The button's name. Null when [child] says it itself, such as in its text.
  required final String? label,

  /// Whether [child] currently takes a tap. Screen readers announce it either way.
  required final bool enabled,

  /// Also shows [label] as a tooltip on hover and long-press, without a
  /// tooltip's own words on the node.
  required final bool showsTooltip,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final node = MergeSemantics(
      child: Semantics(button: true, enabled: enabled, label: label, child: child),
    );
    return switch (label) {
      final String message when showsTooltip => Tooltip(message: message, excludeFromSemantics: true, child: node),
      _ => node,
    };
  }
}
