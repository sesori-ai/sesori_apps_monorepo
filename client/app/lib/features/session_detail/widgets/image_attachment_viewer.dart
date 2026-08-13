import "dart:async";
import "dart:typed_data";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/di/injection.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/external_link.dart";

sealed class const MessageImageViewerImage() {
  ImageProvider get provider;
  Uri? get originalUri;
}

final class const LoadedMessageImage({
  required final Uint8List bytes,
  @override required final ImageProvider provider,
  required final String mime,
  required final String actionFilename,
  @override required final Uri? originalUri,
}) extends MessageImageViewerImage {
  this : super();
}

final class const ViewOnlyMessageImage({
  @override required final ImageProvider provider,
  @override required final Uri? originalUri,
}) extends MessageImageViewerImage {
  this : super();
}

Future<void> showImageAttachmentViewer({
  required BuildContext context,
  required MessageImageViewerImage image,
  required String? filename,
  required Key heroTag,
}) {
  // ignore: no_slop_linter/avoid_navigator_of, the transient viewer must cover the split shell
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final sourceRoute = ModalRoute.of(context);
  if (sourceRoute == null) throw StateError("Image attachment viewer requires a source route");
  final viewerRoute = PageRouteBuilder<void>(
    opaque: false,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) {
      final viewer = ImageAttachmentViewer(
        image: image,
        filename: filename,
        heroTag: heroTag,
      );
      return switch (image) {
        LoadedMessageImage() => BlocProvider(
          create: (_) => ImageAttachmentActionsCubit(
            imageSaver: getIt<ImageSaver>(),
            imageClipboard: getIt<ImageClipboard>(),
            imageSharer: getIt<ImageSharer>(),
            bytes: image.bytes,
            mime: image.mime,
            actionFilename: image.actionFilename,
          ),
          child: viewer,
        ),
        ViewOnlyMessageImage() => viewer,
      };
    },
    transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
  );
  var shouldDismissViewerWithHistory = true;
  // Mirror the root viewer in the session route's local history so Android
  // back dismisses the viewer whichever navigator receives the event first.
  final historyEntry = LocalHistoryEntry(
    impliesAppBarDismissal: false,
    onRemove: () {
      if (shouldDismissViewerWithHistory && viewerRoute.isCurrent) rootNavigator.pop();
    },
  );
  // ignore: no_slop_linter/avoid_raw_go_router, this transient Hero route carries an in-memory ImageProvider that cannot be represented in a URL
  final result = rootNavigator.push<void>(viewerRoute);
  sourceRoute.addLocalHistoryEntry(historyEntry);
  return result.whenComplete(() {
    shouldDismissViewerWithHistory = false;
    historyEntry.remove();
  });
}

class const ImageAttachmentViewer({
  super.key,
  required final MessageImageViewerImage image,
  required final String? filename,
  required final Key heroTag,
}) extends StatefulWidget {
  static const imageKey = ValueKey("imageAttachmentViewer.image");

  @override
  State<ImageAttachmentViewer> createState() => _ImageAttachmentViewerState();
}

class _ImageAttachmentViewerState() extends State<ImageAttachmentViewer> with TickerProviderStateMixin {
  static const _doubleTapScale = 2.5;
  static const _baseScaleTolerance = 0.01;
  static const _dismissVelocity = 900.0;
  static const _dragResetDuration = Duration(milliseconds: 180);
  static const _zoomDuration = Duration(milliseconds: 220);

  final _transformationController = TransformationController();
  late final AnimationController _dragResetController;
  late final AnimationController _zoomController;
  Matrix4Tween? _zoomTween;
  Offset? _doubleTapPosition;
  Offset _interactionDelta = Offset.zero;
  Offset _dragOffset = Offset.zero;
  Offset _dragStartOffset = Offset.zero;
  Offset _dragResetStart = Offset.zero;
  bool _canDragToDismiss = false;
  bool _isDismissDrag = false;
  bool _isDismissing = false;

  bool get _isAtBaseScale => (_transformationController.value.getMaxScaleOnAxis() - 1).abs() <= _baseScaleTolerance;

  @override
  void initState() {
    super.initState();
    _dragResetController = AnimationController(vsync: this, duration: _dragResetDuration)
      ..addListener(_updateDragReset);
    _zoomController = AnimationController(vsync: this, duration: _zoomDuration)..addListener(_updateZoom);
  }

  @override
  void dispose() {
    _dragResetController.dispose();
    _zoomController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _updateDragReset() {
    final progress = Curves.easeOutCubic.transform(_dragResetController.value);
    setState(() => _dragOffset = _dragResetStart * (1 - progress));
  }

  void _updateZoom() {
    final tween = _zoomTween;
    if (tween == null) return;
    final progress = Curves.easeOutCubic.transform(_zoomController.value);
    final transform = tween.transform(progress);
    _transformationController.value = transform;
  }

  void _handleInteractionStart({required ScaleStartDetails details}) {
    _zoomController.stop();
    _interactionDelta = Offset.zero;
    _canDragToDismiss = details.pointerCount == 1 && _isAtBaseScale;
    _isDismissDrag = false;
    if (_canDragToDismiss) {
      _dragStartOffset = _dragOffset;
      _dragResetController.stop();
    }
  }

  void _handleInteractionUpdate({required ScaleUpdateDetails details}) {
    if (!_canDragToDismiss || _isDismissing) return;
    if (details.pointerCount != 1 || !_isAtBaseScale) {
      _canDragToDismiss = false;
      if (_dragOffset != Offset.zero) _animateDragToOrigin();
      return;
    }

    _interactionDelta += details.focalPointDelta;
    if (!_isDismissDrag) {
      if (_interactionDelta.distance < 8) return;
      _isDismissDrag = true;
    }

    final size = MediaQuery.sizeOf(context);
    final nextOffset = _dragStartOffset + _interactionDelta;
    setState(
      () => _dragOffset = Offset(
        nextOffset.dx.clamp(-size.width, size.width),
        nextOffset.dy.clamp(-size.height, size.height),
      ),
    );
  }

  void _handleInteractionEnd({required ScaleEndDetails details}) {
    final wasDismissDrag = _isDismissDrag;
    _canDragToDismiss = false;
    _isDismissDrag = false;
    if (!wasDismissDrag || _isDismissing) {
      if (!_isDismissing && _dragOffset != Offset.zero && !_dragResetController.isAnimating) {
        _animateDragToOrigin();
      }
      return;
    }

    final velocity = details.velocity.pixelsPerSecond;
    final dragDistance = _dragOffset.distance;
    final outwardVelocity = dragDistance == 0
        ? 0.0
        : (velocity.dx * _dragOffset.dx + velocity.dy * _dragOffset.dy) / dragDistance;
    final distanceThreshold = (MediaQuery.sizeOf(context).height * 0.15).clamp(96.0, 160.0);
    if (dragDistance >= distanceThreshold || outwardVelocity >= _dismissVelocity) {
      _dismiss();
    } else {
      _animateDragToOrigin();
    }
  }

  void _animateDragToOrigin() {
    if (context.isReducedMotion) {
      setState(() => _dragOffset = Offset.zero);
      return;
    }
    _dragResetStart = _dragOffset;
    _dragResetController.forward(from: 0);
  }

  void _captureDoubleTapPosition({required TapDownDetails details}) {
    _doubleTapPosition = details.localPosition;
  }

  void _toggleZoom() {
    if (_isDismissing) return;
    final target = _isAtBaseScale ? _zoomedTransform() : Matrix4.identity();
    if (context.isReducedMotion) {
      _transformationController.value = target;
      return;
    }
    _zoomTween = Matrix4Tween(begin: _transformationController.value.clone(), end: target);
    _zoomController.forward(from: 0);
  }

  Matrix4 _zoomedTransform() {
    final position = _doubleTapPosition ?? Offset.zero;
    return Matrix4.identity()
      ..translateByDouble(
        -position.dx * (_doubleTapScale - 1),
        -position.dy * (_doubleTapScale - 1),
        0,
        1,
      )
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, _doubleTapScale, 1);
  }

  void _dismiss() {
    if (_isDismissing) return;
    _isDismissing = true;
    // ignore: no_slop_linter/avoid_navigator_of, dismisses the transient route that owns this viewer
    Navigator.of(context).pop();
  }

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
    final alert = switch (state) {
      ImageAttachmentSaved() => (
        context.loc.sessionDetailImageSaved,
        PregoPopupAlertsNotificationsVariant.success,
      ),
      ImageAttachmentCopied() => (
        context.loc.sessionDetailImageCopied,
        PregoPopupAlertsNotificationsVariant.success,
      ),
      ImageAttachmentSaveAccessDenied() => (
        context.loc.sessionDetailImageSaveAccessDenied,
        PregoPopupAlertsNotificationsVariant.warning,
      ),
      ImageAttachmentCopyFailed() => (
        context.loc.sessionDetailImageCopyFailed,
        PregoPopupAlertsNotificationsVariant.error,
      ),
      ImageAttachmentShareFailed() => (
        context.loc.sessionDetailImageShareFailed,
        PregoPopupAlertsNotificationsVariant.error,
      ),
      ImageAttachmentSaveFailed() => (
        context.loc.sessionDetailImageSaveFailed,
        PregoPopupAlertsNotificationsVariant.error,
      ),
      ImageAttachmentActionsIdle() || ImageAttachmentActionRunning() => null,
    };
    if (alert == null) return;
    final (message, variant) = alert;
    PregoPopupAlertPresenter.of(context).show(title: message, variant: variant);
    context.read<ImageAttachmentActionsCubit>().outcomeHandled();
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final image = widget.image;
    final originalUri = widget.image.originalUri;
    final displayFilename = widget.filename;
    final hasAttachmentActions = image is LoadedMessageImage;
    final isRunningAction =
        hasAttachmentActions && context.watch<ImageAttachmentActionsCubit>().state is ImageAttachmentActionRunning;
    final dismissRange = (MediaQuery.sizeOf(context).height * 0.45).clamp(1.0, double.infinity);
    final dismissProgress = (_dragOffset.distance / dismissRange).clamp(0.0, 1.0);
    final chromeOpacity = 1 - dismissProgress;
    final backgroundOpacity = 1 - dismissProgress * 0.8;
    final viewer = Scaffold(
      backgroundColor: prego.colors.bgSurface1.withValues(alpha: backgroundOpacity),
      body: SafeArea(
        child: Column(
          children: [
            IgnorePointer(
              ignoring: _isDismissDrag,
              child: Opacity(
                opacity: chromeOpacity,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: prego.spacing.sm),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: context.loc.sessionDetailImageClose,
                        onPressed: _dismiss,
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
                              openExternalLink(
                                url: originalUri,
                                mode: UrlLaunchMode.externalApp,
                              ).then<void>((_) {}),
                            ),
                            icon: Icon(Icons.open_in_new, color: prego.colors.textPrimary),
                          ),
                        if (hasAttachmentActions) ...[
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
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Transform.translate(
                offset: _dragOffset,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTapDown: (details) => _captureDoubleTapPosition(details: details),
                  onDoubleTap: _toggleZoom,
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.8,
                    maxScale: 5,
                    onInteractionStart: (details) => _handleInteractionStart(details: details),
                    onInteractionUpdate: (details) => _handleInteractionUpdate(details: details),
                    onInteractionEnd: (details) => _handleInteractionEnd(details: details),
                    child: Hero(
                      tag: widget.heroTag,
                      child: SizedBox.expand(
                        child: Image(
                          key: ImageAttachmentViewer.imageKey,
                          image: image.provider,
                          fit: BoxFit.contain,
                          semanticLabel: widget.filename,
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
              ),
            ),
          ],
        ),
      ),
    );
    if (!hasAttachmentActions) return viewer;
    return BlocListener<ImageAttachmentActionsCubit, ImageAttachmentActionsState>(
      listener: _handleActionState,
      child: viewer,
    );
  }
}
