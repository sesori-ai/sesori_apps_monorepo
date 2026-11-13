import "package:flutter/rendering.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../extensions/command_source_x.dart";
import "../../../widgets/markdown_styles.dart";
import "sent_bubble_landing.dart";
import "user_message_card.dart";

/// A command, skill or MCP prompt the user ran, as an event in the transcript
/// rather than a chat bubble: what ran over the arguments typed with it. It is
/// a record, not a control, so it takes no taps.
class const InvocationCard({
  super.key,
  required final String name,
  required final CommandSource source,
  required final String? arguments,
  required final List<Widget> attachments,

  /// Whether the card waits, outlined, for the harness to take it.
  required final bool outlined,
  required final Duration transitionDuration,
}) extends StatelessWidget {
  static const double _padding = PregoSpacing.lg;

  static const double radius = PregoRadius.x2l;

  static const double _borderWidth = 1;

  /// Space between the surface's edge and its content: the padding and the
  /// border inside it.
  static const double inset = _padding + _borderWidth;

  /// The widest the content may be in a row [rowWidth] wide: the surface is
  /// as wide as a bubble's.
  static double maxContentWidth({required double rowWidth}) =>
      UserMessageBubble.maxContentWidth(rowWidth: rowWidth) + UserMessageBubble.padding * 2 - inset * 2;

  /// The surface's fill and its border, which the pinned prompt paints too.
  static Color fill({required PregoDesignSystem prego}) => prego.colors.bgSecondary;

  static Border border({required PregoDesignSystem prego}) =>
      Border.all(color: prego.colors.borderSecondary, width: _borderWidth);

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    const margin = UserMessageBubble.margin;

    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          container: true,
          label: loc.invocationCardSemantics(source.name, name),
          // A command whose arguments were dictated lands its words here, as a bubble does.
          child: SentBubbleSlot(
            text: arguments,
            child: AnimatedContainer(
              duration: transitionDuration,
              curve: Curves.easeInOutCubic,
              margin: margin,
              padding: const EdgeInsets.all(_padding),
              constraints: BoxConstraints(
                maxWidth: maxContentWidth(rowWidth: constraints.maxWidth) + inset * 2,
              ),
              decoration: BoxDecoration(
                color: fill(prego: prego),
                border: border(prego: prego),
                borderRadius: BorderRadius.circular(radius),
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: prego.colors.borderBrand.withValues(alpha: outlined ? 0.55 : 0),
                ),
              ),
              child: InvocationCardContent(
                name: name,
                source: source,
                arguments: arguments,
                attachments: attachments,
                onHeaderLayout: null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An invocation card's content without its surface: the kind and what ran,
/// over the attachments and the arguments. The pinned prompt paints this same
/// content on its own copy of the surface, so a pin and the card it stands in
/// for are pixel-identical.
class const InvocationCardContent({
  super.key,
  required final String name,
  required final CommandSource source,
  required final String? arguments,
  required final List<Widget> attachments,

  /// Told the header's height each time it lays out, so a pin can compact to
  /// the header and the start of the arguments; null when nothing asks.
  required final ValueSetter<double>? onHeaderLayout,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final arguments = this.arguments;
    final onHeaderLayout = this.onHeaderLayout;
    final header = ExcludeSemantics(
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PregoTag(
            icon: source.icon,
            label: source.label(loc: loc),
          ),
          const SizedBox(height: PregoSpacing.md),
          Text(
            loc.invocationCardRan(name),
            // The arguments' own size, so the two read as one message at every scale.
            style: (buildChatMessageMarkdownStyleSheet(prego: prego).p ?? prego.textTheme.textMd.regular).copyWith(
              fontWeight: FontWeight.w500,
              color: prego.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onHeaderLayout == null) header else _HeaderExtent(onLayout: onHeaderLayout, child: header),
        if (attachments.isNotEmpty || arguments != null) ...[
          const SizedBox(height: bodyGap),
          UserMessageBubbleContent(markdown: arguments, attachments: attachments, alignment: .start),
        ],
      ],
    );
  }

  /// Space between the header and the arguments.
  static const double bodyGap = PregoSpacing.sm;
}

/// Reports its child's height as it lays out.
class const _HeaderExtent({required final ValueSetter<double> onLayout, required super.child})
    extends SingleChildRenderObjectWidget {
  @override
  _RenderHeaderExtent createRenderObject(BuildContext context) => _RenderHeaderExtent(onLayout: onLayout);

  @override
  void updateRenderObject(BuildContext context, _RenderHeaderExtent renderObject) {
    renderObject.onLayout = onLayout;
  }
}

class _RenderHeaderExtent({required var ValueSetter<double> onLayout}) extends RenderProxyBox {
  @override
  void performLayout() {
    super.performLayout();
    onLayout(size.height);
  }
}
