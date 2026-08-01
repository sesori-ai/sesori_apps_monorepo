import "dart:async";
import "dart:typed_data";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/di/injection.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/external_link.dart";

final class LoadedMessageImage {
  final Uint8List bytes;
  final ImageProvider provider;
  final String mime;
  final String actionFilename;
  final Uri? originalUri;

  const LoadedMessageImage({
    required this.bytes,
    required this.provider,
    required this.mime,
    required this.actionFilename,
    required this.originalUri,
  });
}

Future<void> showImageAttachmentViewer({
  required BuildContext context,
  required LoadedMessageImage image,
  required String? filename,
  required Key heroTag,
}) {
  // ignore: no_slop_linter/avoid_navigator_of, no_slop_linter/avoid_raw_go_router, this transient Hero route carries an in-memory ImageProvider that cannot be represented in a URL
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => BlocProvider(
        create: (_) => ImageAttachmentActionsCubit(
          imageSaver: getIt<ImageSaver>(),
          imageClipboard: getIt<ImageClipboard>(),
          imageSharer: getIt<ImageSharer>(),
          bytes: image.bytes,
          mime: image.mime,
          actionFilename: image.actionFilename,
        ),
        child: ImageAttachmentViewer(
          image: image,
          filename: filename,
          heroTag: heroTag,
        ),
      ),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ),
  );
}

class ImageAttachmentViewer extends StatelessWidget {
  static const imageKey = ValueKey("imageAttachmentViewer.image");

  final LoadedMessageImage image;
  final String? filename;
  final Key heroTag;

  const ImageAttachmentViewer({
    super.key,
    required this.image,
    required this.filename,
    required this.heroTag,
  });

  ImageShareOrigin? _shareOrigin({required BuildContext originContext}) {
    final renderObject = originContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached || !renderObject.hasSize) return null;
    final origin = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    return ImageShareOrigin(
      left: origin.left,
      top: origin.top,
      width: origin.width,
      height: origin.height,
    );
  }

  // ignore: no_slop_linter/prefer_required_named_parameters, callback signature is defined by BlocListener
  void _handleActionState(BuildContext context, ImageAttachmentActionsState state) {
    final message = switch (state) {
      ImageAttachmentSaved() => context.loc.sessionDetailImageSaved,
      ImageAttachmentCopied() => context.loc.sessionDetailImageCopied,
      ImageAttachmentSaveAccessDenied() => context.loc.sessionDetailImageSaveAccessDenied,
      ImageAttachmentCopyFailed() => context.loc.sessionDetailImageCopyFailed,
      ImageAttachmentShareFailed() => context.loc.sessionDetailImageShareFailed,
      ImageAttachmentSaveFailed() => context.loc.sessionDetailImageSaveFailed,
      ImageAttachmentActionsIdle() || ImageAttachmentActionRunning() => null,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    context.read<ImageAttachmentActionsCubit>().outcomeHandled();
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final originalUri = image.originalUri;
    final displayFilename = filename;
    final isRunningAction = context.watch<ImageAttachmentActionsCubit>().state is ImageAttachmentActionRunning;
    return BlocListener<ImageAttachmentActionsCubit, ImageAttachmentActionsState>(
      listener: _handleActionState,
      child: Scaffold(
        backgroundColor: prego.colors.bgSurface1,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: prego.spacing.sm),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: context.loc.sessionDetailImageClose,
                      onPressed: context.pop,
                      icon: Icon(Icons.close, color: prego.colors.textPrimary),
                    ),
                    SizedBox(width: prego.spacing.xs),
                    Expanded(
                      child: displayFilename == null
                          ? const SizedBox.shrink()
                          : Text(
                              displayFilename,
                              style: prego.textTheme.textSm.bold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    if (isRunningAction)
                      Padding(
                        padding: EdgeInsets.all(prego.spacing.md),
                        child: SizedBox.square(
                          dimension: prego.spacing.x2l,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: prego.colors.fgBrandPrimary,
                          ),
                        ),
                      )
                    else ...[
                      if (originalUri != null)
                        IconButton(
                          tooltip: context.loc.sessionDetailImageOpenOriginal,
                          onPressed: () => unawaited(
                            openExternalLink(url: originalUri, mode: UrlLaunchMode.externalApp).then<void>((_) {}),
                          ),
                          icon: Icon(Icons.open_in_new, color: prego.colors.textPrimary),
                        ),
                      IconButton(
                        tooltip: context.loc.sessionDetailImageCopy,
                        onPressed: () => unawaited(context.read<ImageAttachmentActionsCubit>().copy()),
                        icon: Icon(Icons.content_copy, color: prego.colors.textPrimary),
                      ),
                      Builder(
                        builder: (buttonContext) => IconButton(
                          tooltip: context.loc.sessionDetailImageShare,
                          onPressed: () => unawaited(
                            context.read<ImageAttachmentActionsCubit>().share(
                              origin: _shareOrigin(originContext: buttonContext),
                            ),
                          ),
                          icon: Icon(Icons.share_outlined, color: prego.colors.textPrimary),
                        ),
                      ),
                      IconButton(
                        tooltip: context.loc.sessionDetailImageSave,
                        onPressed: () => unawaited(context.read<ImageAttachmentActionsCubit>().save()),
                        icon: Icon(Icons.download_outlined, color: prego.colors.textPrimary),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Hero(
                    tag: heroTag,
                    child: SizedBox.expand(
                      child: Image(
                        key: ImageAttachmentViewer.imageKey,
                        image: image.provider,
                        fit: BoxFit.contain,
                        semanticLabel: filename,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.broken_image,
                          size: prego.spacing.x6l,
                          color: prego.colors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
