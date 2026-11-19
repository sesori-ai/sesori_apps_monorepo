import "dart:async";
import "dart:typed_data";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../widgets/image_attachment_viewer.dart";

const _maxDecodedImageDimension = 2048;
const _fadeDuration = Duration(milliseconds: 220);

/// One image of a question page, in a box at the size the agent's file
/// declared, so nothing below it moves as it loads: a shimmer, then the image
/// fading in, or a neutral placeholder when it can't load. Tapping a loaded
/// image opens it in the image viewer.
class const QuestionPageImage({
  super.key,
  required final PageImage image,

  /// The tallest the box may be; a tall image narrows to fit.
  required final double maxHeight,
}) extends StatefulWidget {
  @override
  State<QuestionPageImage> createState() => _QuestionPageImageState();
}

class _QuestionPageImageState() extends State<QuestionPageImage> {
  final _heroTag = UniqueKey();
  late final Future<Uint8List?> _bytes = context.read<PendingPageCubit>().loadImage(image: widget.image);

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final caption = widget.image.caption;
    // A file that declared no size still gets a box rather than failing layout.
    final aspectRatio = widget.image.width > 0 && widget.image.height > 0
        ? widget.image.width / widget.image.height
        : 16 / 9;
    final box = LayoutBuilder(
      builder: (context, constraints) {
        var width = constraints.maxWidth;
        if (width / aspectRatio > widget.maxHeight) width = widget.maxHeight * aspectRatio;
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            key: const Key("question-page-image-box"),
            width: width,
            height: width / aspectRatio,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PregoRadius.lg),
              child: FutureBuilder<Uint8List?>(
                future: _bytes,
                builder: (context, snapshot) => switch (snapshot) {
                  AsyncSnapshot(connectionState: ConnectionState.done, data: final bytes?) => _Loaded(
                    bytes: bytes,
                    heroTag: _heroTag,
                    caption: caption,
                  ),
                  AsyncSnapshot(connectionState: ConnectionState.done) => const _Unavailable(),
                  AsyncSnapshot() => const _Loading(leaving: false),
                },
              ),
            ),
          ),
        );
      },
    );
    if (caption == null) return box;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        box,
        const SizedBox(height: PregoSpacing.sm),
        Text(caption, style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary)),
      ],
    );
  }
}

class const _Loading({required final bool leaving}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PregoShimmer(
    leaving: leaving,
    appearDelay: Duration.zero,
    child: ColoredBox(color: context.prego.colors.bgTertiary, child: const SizedBox.expand()),
  );
}

class const _Unavailable() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return ColoredBox(
      key: const Key("question-page-image-unavailable"),
      color: prego.colors.bgSecondary,
      child: Center(
        child: Icon(
          TablerRegular.photo_off,
          size: PregoIconSize.lg,
          color: prego.colors.fgQuaternary,
          semanticLabel: context.loc.questionPageImageUnavailable,
        ),
      ),
    );
  }
}

/// The decoded image fades in over the shimmer, which then fades away.
class const _Loaded({
  required final Uint8List bytes,
  required final Key heroTag,
  required final String? caption,
}) extends StatefulWidget {
  @override
  State<_Loaded> createState() => _LoadedState();
}

class _LoadedState() extends State<_Loaded> {
  // Bounded like the chat's attachment viewer, so a huge image cannot exhaust
  // memory when decoded.
  late final ImageProvider _provider = ResizeImage(
    MemoryImage(widget.bytes),
    width: _maxDecodedImageDimension,
    height: _maxDecodedImageDimension,
    policy: ResizeImagePolicy.fit,
  );
  bool _shown = false;
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    if (_failed) return const _Unavailable();
    final duration = context.isReducedMotion ? Duration.zero : _fadeDuration;
    return Semantics(
      button: true,
      label: context.loc.sessionDetailImageOpen,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _shown
            ? () => unawaited(
                showImageAttachmentViewer(
                  context: context,
                  image: ViewOnlyMessageImage(provider: _provider, originalUri: null),
                  heroPresentation: ImageAttachmentHeroPresentation.contained,
                  filename: widget.caption,
                  heroTag: widget.heroTag,
                ),
              )
            : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _Loading(leaving: _shown),
            Hero(
              tag: widget.heroTag,
              child: Image(
                image: _provider,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, _) {
                  if (frame != null && !_shown) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _shown = true);
                    });
                  }
                  return AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: duration, child: child);
                },
                errorBuilder: (context, error, stackTrace) {
                  logw("Failed to decode a question page image", error, stackTrace);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _failed = true);
                  });
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
