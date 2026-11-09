import "dart:math" as math;

import "package:material_ui/material_ui.dart";

import "../../icons/tabler_icons.g.dart";
import "../../interactions/prego_tappable.dart";
import "../../theme/prego_theme.dart";

/// Staged image tile from Figma's Add files container (4590:9921).
/// The caller supplies the image and owns its bytes, opening, and removal.
class const PregoImageAttachmentPreview({
  super.key,
  required final Widget image,
  required final String imageLabel,
  required final VoidCallback onOpen,
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
            button: true,
            label: imageLabel,
            child: PregoTappable(
              onTap: onOpen,
              borderRadius: radius,
              containerBuilder: (child) => child,
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
          ),
          _RemoveBadge(label: removeLabel, onRemove: onRemove, radius: radius),
        ],
      ),
    );
  }
}

/// A staged file's tile, the same square as [PregoImageAttachmentPreview]: a
/// file glyph over the file's extension. A file has no preview to open, so
/// its name is the tooltip and the semantics label.
class const PregoFileAttachmentPreview({
  super.key,
  required final String fileName,
  required final String removeLabel,
  required final VoidCallback onRemove,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: PregoImageAttachmentPreview.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            label: fileName,
            child: Tooltip(
              message: fileName,
              excludeFromSemantics: true,
              child: ExcludeSemantics(child: PregoFileAttachmentFace(fileName: fileName)),
            ),
          ),
          _RemoveBadge(label: removeLabel, onRemove: onRemove, radius: BorderRadius.circular(PregoRadius.lg)),
        ],
      ),
    );
  }
}

/// What a file attachment shows in place of a thumbnail: a file glyph over the
/// file's extension, filling the square it is given.
class const PregoFileAttachmentFace({super.key, required final String fileName}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final dot = fileName.lastIndexOf(".");
    final extension = dot > 0 && dot < fileName.length - 1 ? fileName.substring(dot + 1).toUpperCase() : null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: prego.colors.bgSurface2,
        borderRadius: BorderRadius.circular(PregoRadius.lg),
        border: Border.all(color: prego.colors.borderSecondary),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xs),
        // The square doesn't grow with the text size, so a large text size or a
        // long extension shrinks the glyph and label together to fit.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(TablerRegular.file, size: PregoIconSize.md, color: prego.colors.textSecondary),
              if (extension != null)
                Text(
                  extension,
                  maxLines: 1,
                  style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The remove badge in a staged tile's top corner.
class const _RemoveBadge({
  required final String label,
  required final VoidCallback onRemove,
  required final BorderRadius radius,
}) extends StatelessWidget {
  static const double _targetSize = 24;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return PositionedDirectional(
      top: 0,
      end: 0,
      child: Semantics(
        button: true,
        label: label,
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: PregoTappable(
            onTap: onRemove,
            borderRadius: radius,
            // Just past the badge, so the rest of the tile stays the tile's.
            containerBuilder: (child) => SizedBox.square(dimension: _targetSize, child: child),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: 3, end: 4),
              child: Align(
                alignment: AlignmentDirectional.topEnd,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: prego.colors.bgSurface5, shape: BoxShape.circle),
                  // Fits the 14pt badge; smaller than any icon token.
                  child: Icon(TablerRegular.x, size: 10, color: prego.colors.textPrimary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One fixed-height row of [PregoImageAttachmentPreview] and
/// [PregoFileAttachmentPreview] tiles. Edge fades hint at tiles offscreen in
/// either direction, clearing at each end so its tile and remove button stay
/// visible.
class const PregoImageAttachmentStrip({
  super.key,

  /// Each a [PregoImageAttachmentPreview.size] square.
  required final List<Widget> children,
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
            final scrollExtent = math.max(0.0, contentWidth - constraints.maxWidth);
            // Removing images can leave the old offset until scroll layout
            // catches up; derive both fades from the current content bounds.
            final offset = (_scrollController.hasClients ? _scrollController.offset : 0.0).clamp(0.0, scrollExtent);
            // Mirror Figma's 128.5px trailing fade at the leading edge. Keep
            // the two gradient ramps from overlapping in a smaller viewport.
            final maxFadeWidth = math.min(128.5, constraints.maxWidth / 2);
            final leadingFadeWidth = math.min(maxFadeWidth, offset);
            final trailingFadeWidth = math.min(maxFadeWidth, scrollExtent - offset);
            return ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: [
                  leadingFadeWidth == 0 ? Colors.white : Colors.transparent,
                  Colors.white,
                  Colors.white,
                  trailingFadeWidth == 0 ? Colors.white : Colors.transparent,
                ],
                stops: [
                  0,
                  leadingFadeWidth == 0 ? 0 : leadingFadeWidth / bounds.width,
                  trailingFadeWidth == 0 ? 1 : 1 - trailingFadeWidth / bounds.width,
                  1,
                ],
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
