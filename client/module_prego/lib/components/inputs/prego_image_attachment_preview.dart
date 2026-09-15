import "dart:math" as math;

import "package:material_ui/material_ui.dart";

import "../../icons/tabler_icons.g.dart";
import "../../interactions/prego_tappable.dart";
import "../../theme/prego_theme.dart";

/// Staged image tile from Figma's Add files container (4590:9921).
/// The caller supplies the image and owns its bytes and removal.
class const PregoImageAttachmentPreview({
  super.key,
  required final Widget image,
  required final String imageLabel,
  required final String removeLabel,
  required final VoidCallback onRemove,
}) extends StatelessWidget {
  static const double size = 52;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final radius = BorderRadius.circular(PregoRadius.lg);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            image: true,
            label: imageLabel,
            child: ExcludeSemantics(
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: prego.colors.borderSecondary),
                ),
                child: ClipRRect(borderRadius: radius, child: image),
              ),
            ),
          ),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: Semantics(
              button: true,
              label: removeLabel,
              child: Tooltip(
                message: removeLabel,
                excludeFromSemantics: true,
                child: PregoTappable(
                  onTap: onRemove,
                  borderRadius: radius,
                  containerBuilder: (child) => SizedBox.square(dimension: 44, child: child),
                  // Keep the Figma badge small without shrinking its tap target.
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(top: 3, end: 4),
                    child: Align(
                      alignment: AlignmentDirectional.topEnd,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(color: prego.colors.bgSurface5, shape: BoxShape.circle),
                        child: Icon(TablerRegular.x, size: 10, color: prego.colors.textPrimary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One fixed-height row. The trailing fade hints at images still offscreen,
/// then recedes so the final image and its remove button are fully visible.
class const PregoImageAttachmentStrip({
  super.key,
  required final List<PregoImageAttachmentPreview> children,
}) extends StatefulWidget {
  @override
  State<PregoImageAttachmentStrip> createState() => _PregoImageAttachmentStripState();
}

class _PregoImageAttachmentStripState() extends State<PregoImageAttachmentStrip> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final contentWidth =
        widget.children.length * PregoImageAttachmentPreview.size +
        math.max(0, widget.children.length - 1) * PregoSpacing.md;
    return SizedBox(
      height: PregoImageAttachmentPreview.size,
      child: LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
          animation: _scrollController,
          builder: (context, child) {
            final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
            // Figma's 364px mask fades over its final 128.5px.
            final fadeWidth = math.min(128.5, math.max(0.0, contentWidth - constraints.maxWidth - offset));
            return ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: [Colors.white, fadeWidth == 0 ? Colors.white : Colors.transparent],
                stops: [fadeWidth == 0 ? 0 : (1 - fadeWidth / bounds.width).clamp(0.0, 1.0), 1],
              ).createShader(bounds, textDirection: textDirection),
              child: child,
            );
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: Row(spacing: PregoSpacing.md, children: widget.children),
          ),
        ),
      ),
    );
  }
}
