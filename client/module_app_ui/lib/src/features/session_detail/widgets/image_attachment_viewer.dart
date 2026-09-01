import "dart:async";
import "dart:typed_data";

import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../session_detail_presentation_scope.dart";

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

final class const StoredMessageImage({
  required final ViewOnlyMessageImage thumbnail,
  required final MessageImageCubit cubit,
}) extends MessageImageViewerImage {
  this : super();

  @override
  ImageProvider get provider => thumbnail.provider;

  @override
  Uri? get originalUri => thumbnail.originalUri;
}

Future<void> showImageAttachmentViewer({
  required BuildContext context,
  required MessageImageViewerImage image,
  required ImageAttachmentHeroPresentation heroPresentation,
  required String? filename,
  required Key heroTag,
}) {
  final presentation = SessionDetailPresentationScope.read(context);
  // ignore: no_slop_linter/avoid_navigator_of, the transient viewer must cover the split shell
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final sourceRoute = ModalRoute.of(context);
  if (sourceRoute == null) throw StateError("Image attachment viewer requires a source route");
  final viewerRoute = PageRouteBuilder<void>(
    opaque: false,
    transitionDuration: context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 260),
    reverseTransitionDuration: context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => SessionDetailPresentationScope(
      messageImageRepository: presentation.messageImageRepository,
      imageSaver: presentation.imageSaver,
      imageClipboard: presentation.imageClipboard,
      imageSharer: presentation.imageSharer,
      openExternalLink: presentation.openExternalLink,
      openSession: presentation.openSession,
      child: switch (image) {
        LoadedMessageImage() => ImageAttachmentViewer(
          image: image,
          flightImageProvider: image.provider,
          heroPresentation: heroPresentation,
          filename: filename,
          heroTag: heroTag,
          originalPresentation: ImageAttachmentOriginalPresentation.idle,
          onRetryOriginal: null,
        ),
        ViewOnlyMessageImage() => ImageAttachmentViewer(
          image: image,
          flightImageProvider: image.provider,
          heroPresentation: heroPresentation,
          filename: filename,
          heroTag: heroTag,
          originalPresentation: ImageAttachmentOriginalPresentation.idle,
          onRetryOriginal: null,
        ),
        StoredMessageImage() => _StoredImageAttachmentViewer(
          image: image,
          heroPresentation: heroPresentation,
          filename: filename,
          heroTag: heroTag,
        ),
      },
    ),
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
  // Hold the mirror entry until the viewer's exit transition finishes, not just
  // until it is popped. Android's back gesture can deliver a second pop right
  // after the one that dismissed the viewer; while the entry is still there the
  // session route absorbs it instead of leaving the session.
  unawaited(
    viewerRoute.completed.whenComplete(() {
      shouldDismissViewerWithHistory = false;
      // The transition also completes when the whole navigator is torn down,
      // where the session route is already gone and has nothing left to update.
      if (sourceRoute.isActive) historyEntry.remove();
    }),
  );
  return result;
}

ImageAttachmentActionsCubit _createActionsCubit({
  required BuildContext context,
  required LoadedMessageImage image,
}) {
  final presentation = SessionDetailPresentationScope.read(context);
  return ImageAttachmentActionsCubit(
    imageSaver: presentation.imageSaver(),
    imageClipboard: presentation.imageClipboard(),
    imageSharer: presentation.imageSharer(),
    bytes: image.bytes,
    mime: image.mime,
    actionFilename: image.actionFilename,
  );
}

class const _StoredImageAttachmentViewer({
  required final StoredMessageImage image,
  required final ImageAttachmentHeroPresentation heroPresentation,
  required final String? filename,
  required final Key heroTag,
}) extends StatefulWidget {
  @override
  State<_StoredImageAttachmentViewer> createState() => _StoredImageAttachmentViewerState();
}

class _StoredImageAttachmentViewerState() extends State<_StoredImageAttachmentViewer> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.image.cubit.loadOriginal());
  }

  @override
  void dispose() {
    widget.image.cubit.releaseOriginal();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _StoredImageAttachmentViewerContent(
    thumbnail: widget.image.thumbnail,
    cubit: widget.image.cubit,
    heroPresentation: widget.heroPresentation,
    filename: widget.filename,
    heroTag: widget.heroTag,
  );
}

enum ImageAttachmentOriginalPresentation() {
  idle,
  loading,
  failed,
}

enum ImageAttachmentHeroPresentation() {
  cropped,
  contained,
}

class const _StoredImageAttachmentViewerContent({
  required final ViewOnlyMessageImage thumbnail,
  required final MessageImageCubit cubit,
  required final ImageAttachmentHeroPresentation heroPresentation,
  required final String? filename,
  required final Key heroTag,
}) extends StatefulWidget {
  @override
  State<_StoredImageAttachmentViewerContent> createState() => _StoredImageAttachmentViewerContentState();
}

class _StoredImageAttachmentViewerContentState() extends State<_StoredImageAttachmentViewerContent> {
  late final StreamSubscription<MessageImageState> _stateSubscription;
  late MessageImageOriginalState _original;
  MemoryImage? _originalProvider;
  ImageStream? _decodeStream;
  ImageStreamListener? _decodeListener;
  LoadedMessageImage? _decodedOriginal;
  bool _decodeFailed = false;

  @override
  void initState() {
    super.initState();
    _original = widget.cubit.state.original;
    _stateSubscription = widget.cubit.stream.listen((state) {
      if (!mounted) return;
      setState(() => _original = state.original);
      _processOriginal();
    });
    _processOriginal();
  }

  @override
  void dispose() {
    unawaited(_stateSubscription.cancel());
    _clearOriginal();
    super.dispose();
  }

  void _processOriginal() {
    if (_original case MessageImageOriginalLoaded(:final bytes, :final mime, :final actionFilename)) {
      if (_originalProvider == null && _decodedOriginal == null) {
        _startDecode(bytes: bytes, mime: mime, actionFilename: actionFilename);
      }
    } else {
      _clearOriginal();
      _decodeFailed = false;
    }
  }

  void _startDecode({required Uint8List bytes, required String mime, required String actionFilename}) {
    _clearOriginal();
    _decodeFailed = false;
    final provider = MemoryImage(bytes);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, synchronousCall) {
        if (!identical(_originalProvider, provider)) return;
        void acceptOriginal() {
          if (!mounted || !identical(_originalProvider, provider)) return;
          _removeDecodeListener();
          final loaded = LoadedMessageImage(
            bytes: bytes,
            provider: provider,
            mime: mime,
            actionFilename: actionFilename,
            originalUri: null,
          );
          setState(() => _decodedOriginal = loaded);
        }

        if (synchronousCall) {
          scheduleMicrotask(acceptOriginal);
        } else {
          acceptOriginal();
        }
      },
      onError: (error, stackTrace) {
        if (!identical(_originalProvider, provider)) return;
        logw("Failed to decode a stored message image original", error, stackTrace);
        _removeDecodeListener();
        unawaited(provider.evict());
        if (!mounted) return;
        setState(() => _decodeFailed = true);
      },
    );
    _originalProvider = provider;
    _decodeStream = stream;
    _decodeListener = listener;
    stream.addListener(listener);
  }

  void _removeDecodeListener() {
    final stream = _decodeStream;
    final listener = _decodeListener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _decodeStream = null;
    _decodeListener = null;
  }

  void _clearOriginal() {
    _removeDecodeListener();
    _decodedOriginal = null;
    final provider = _originalProvider;
    _originalProvider = null;
    if (provider != null) unawaited(provider.evict());
  }

  void _retryOriginal() {
    widget.cubit.releaseOriginal();
    unawaited(widget.cubit.retryOriginal());
  }

  @override
  Widget build(BuildContext context) {
    final presentation = switch (_original) {
      MessageImageOriginalLoading() => ImageAttachmentOriginalPresentation.loading,
      MessageImageOriginalLoaded() when _decodedOriginal == null && !_decodeFailed =>
        ImageAttachmentOriginalPresentation.loading,
      MessageImageOriginalLoaded() when _decodeFailed => ImageAttachmentOriginalPresentation.failed,
      MessageImageOriginalRejected() ||
      MessageImageOriginalFailed() ||
      MessageImageOriginalUnavailable() => ImageAttachmentOriginalPresentation.failed,
      MessageImageOriginalAvailable() || MessageImageOriginalLoaded() => ImageAttachmentOriginalPresentation.idle,
    };
    return ImageAttachmentViewer(
      image: _decodedOriginal ?? widget.thumbnail,
      flightImageProvider: widget.thumbnail.provider,
      heroPresentation: widget.heroPresentation,
      filename: widget.filename,
      heroTag: widget.heroTag,
      originalPresentation: presentation,
      onRetryOriginal: _retryOriginal,
    );
  }
}

class const ImageAttachmentViewer({
  super.key,
  required final MessageImageViewerImage image,
  required final ImageProvider flightImageProvider,
  required final ImageAttachmentHeroPresentation heroPresentation,
  required final String? filename,
  required final Key heroTag,
  required final ImageAttachmentOriginalPresentation originalPresentation,
  required final VoidCallback? onRetryOriginal,
}) extends StatefulWidget {
  static const imageKey = ValueKey("imageAttachmentViewer.image");
  static const flightCropImageKey = ValueKey("imageAttachmentViewer.flightCropImage");
  static const flightFullImageKey = ValueKey("imageAttachmentViewer.flightFullImage");

  @override
  State<ImageAttachmentViewer> createState() => _ImageAttachmentViewerState();
}

class _ImageAttachmentViewerState() extends State<ImageAttachmentViewer> with TickerProviderStateMixin {
  static const _doubleTapScale = 2.5;
  static const _baseScaleTolerance = 0.01;
  static const _dismissVelocity = 900.0;
  static const _dragResetDuration = Duration(milliseconds: 180);
  static const _imageSwapDuration = Duration(milliseconds: 180);
  static const _zoomDuration = Duration(milliseconds: 220);

  final _transformationController = TransformationController();
  ImageStream? _flightImageStream;
  ImageStreamListener? _flightImageStreamListener;
  double? _flightImageAspectRatio;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveFlightImageAspectRatio();
  }

  @override
  void didUpdateWidget(covariant ImageAttachmentViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flightImageProvider != widget.flightImageProvider) _resolveFlightImageAspectRatio();
  }

  @override
  void dispose() {
    _removeFlightImageStreamListener();
    _dragResetController.dispose();
    _zoomController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _resolveFlightImageAspectRatio() {
    final stream = widget.flightImageProvider.resolve(createLocalImageConfiguration(context));
    if (_flightImageStream?.key == stream.key) return;
    _removeFlightImageStreamListener();
    _flightImageAspectRatio = null;
    final listener = ImageStreamListener(
      (image, _) {
        final aspectRatio = image.image.width / image.image.height;
        image.dispose();
        _removeFlightImageStreamListener();
        if (!mounted || _flightImageAspectRatio == aspectRatio) return;
        setState(() => _flightImageAspectRatio = aspectRatio);
      },
      // The visible Image's errorBuilder owns decode failure presentation.
      onError: (_, _) {
        _removeFlightImageStreamListener();
        if (!mounted || _flightImageAspectRatio == null) return;
        setState(() => _flightImageAspectRatio = null);
      },
      reportErrors: false,
    );
    _flightImageStream = stream;
    _flightImageStreamListener = listener;
    stream.addListener(listener);
  }

  void _removeFlightImageStreamListener() {
    final stream = _flightImageStream;
    final listener = _flightImageStreamListener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _flightImageStream = null;
    _flightImageStreamListener = null;
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

  // ignore: no_slop_linter/prefer_required_named_parameters, matches Flutter's HeroFlightShuttleBuilder
  Widget _buildHeroFlight(
    BuildContext _,
    Animation<double> animation,
    HeroFlightDirection _,
    BuildContext _,
    BuildContext _,
  ) {
    final provider = widget.flightImageProvider;
    if (widget.heroPresentation == ImageAttachmentHeroPresentation.contained) {
      return Image(
        key: ImageAttachmentViewer.flightFullImageKey,
        image: provider,
        fit: BoxFit.contain,
        gaplessPlayback: true,
      );
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) {
        final containedOpacity = Curves.easeInOut.transform(animation.value);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: 1 - containedOpacity,
                child: Image(
                  key: ImageAttachmentViewer.flightCropImageKey,
                  image: provider,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
              Opacity(
                opacity: containedOpacity,
                child: Image(
                  key: ImageAttachmentViewer.flightFullImageKey,
                  image: provider,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImage({required MessageImageViewerImage image}) {
    return Semantics(
      image: true,
      label: widget.filename,
      child: ExcludeSemantics(
        child: AnimatedSwitcher(
          duration: context.isReducedMotion ? Duration.zero : _imageSwapDuration,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeOut,
          layoutBuilder: (currentChild, previousChildren) => Stack(
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              ?currentChild,
            ],
          ),
          child: KeyedSubtree(
            key: ObjectKey(image.provider),
            child: Image(
              key: ImageAttachmentViewer.imageKey,
              image: image.provider,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Icon(
                Icons.broken_image,
                size: context.prego.spacing.x6l,
                color: context.prego.colors.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
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

  void _handleActionState({required BuildContext context, required ImageAttachmentActionsState state}) {
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

  Widget _buildToolbar({
    required BuildContext context,
    required ImageAttachmentActionsCubit? actionsCubit,
    required bool isRunningAction,
    required double opacity,
  }) {
    final prego = context.prego;
    final originalUri = widget.image.originalUri;
    final displayFilename = widget.filename;
    return IgnorePointer(
      ignoring: _isDismissDrag,
      child: Opacity(
        opacity: opacity,
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
                    child: PregoActivityIndicator(color: prego.colors.fgBrandPrimary),
                  ),
                )
              else ...[
                if (originalUri != null)
                  IconButton(
                    tooltip: context.loc.sessionDetailImageOpenOriginal,
                    onPressed: () => unawaited(
                      SessionDetailPresentationScope.read(context)
                          .openExternalLink(
                            url: originalUri,
                            mode: UrlLaunchMode.externalApp,
                          )
                          .then<void>((_) {}),
                    ),
                    icon: Icon(Icons.open_in_new, color: prego.colors.textPrimary),
                  ),
                if (actionsCubit != null) ...[
                  IconButton(
                    tooltip: context.loc.sessionDetailImageCopy,
                    onPressed: () => unawaited(actionsCubit.copy()),
                    icon: Icon(Icons.content_copy, color: prego.colors.textPrimary),
                  ),
                  Builder(
                    builder: (buttonContext) => IconButton(
                      tooltip: context.loc.sessionDetailImageShare,
                      onPressed: () => unawaited(
                        actionsCubit.share(
                          origin: _shareOrigin(originContext: buttonContext),
                        ),
                      ),
                      icon: Icon(Icons.share_outlined, color: prego.colors.textPrimary),
                    ),
                  ),
                  IconButton(
                    tooltip: context.loc.sessionDetailImageSave,
                    onPressed: () => unawaited(actionsCubit.save()),
                    icon: Icon(Icons.download_outlined, color: prego.colors.textPrimary),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final image = widget.image;
    final imagePresentation = _buildImage(image: image);
    final heroChild = switch (_flightImageAspectRatio) {
      final aspectRatio? => AspectRatio(aspectRatio: aspectRatio, child: imagePresentation),
      null => SizedBox.expand(child: imagePresentation),
    };
    final dismissRange = (MediaQuery.sizeOf(context).height * 0.45).clamp(1.0, double.infinity);
    final dismissProgress = (_dragOffset.distance / dismissRange).clamp(0.0, 1.0);
    final chromeOpacity = 1 - dismissProgress;
    final backgroundOpacity = 1 - dismissProgress * 0.8;
    final viewer = Scaffold(
      backgroundColor: prego.colors.bgSurface1.withValues(alpha: backgroundOpacity),
      body: SafeArea(
        child: Column(
          children: [
            switch (image) {
              final LoadedMessageImage image => BlocProvider(
                key: ObjectKey(image),
                create: (context) => _createActionsCubit(context: context, image: image),
                child: BlocListener<ImageAttachmentActionsCubit, ImageAttachmentActionsState>(
                  listener: (context, state) => _handleActionState(context: context, state: state),
                  child: Builder(
                    builder: (context) {
                      final actionsCubit = context.read<ImageAttachmentActionsCubit>();
                      return _buildToolbar(
                        context: context,
                        actionsCubit: actionsCubit,
                        isRunningAction:
                            context.watch<ImageAttachmentActionsCubit>().state is ImageAttachmentActionRunning,
                        opacity: chromeOpacity,
                      );
                    },
                  ),
                ),
              ),
              ViewOnlyMessageImage() || StoredMessageImage() => _buildToolbar(
                context: context,
                actionsCubit: null,
                isRunningAction: false,
                opacity: chromeOpacity,
              ),
            },
            Expanded(
              child: Stack(
                children: [
                  Transform.translate(
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
                        child: Center(
                          child: Hero(
                            tag: widget.heroTag,
                            flightShuttleBuilder: _buildHeroFlight,
                            child: heroChild,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.originalPresentation == ImageAttachmentOriginalPresentation.loading)
                    PositionedDirectional(
                      bottom: prego.spacing.lg,
                      end: prego.spacing.lg,
                      child: PregoActivityIndicator(color: prego.colors.fgBrandPrimary),
                    ),
                  if (widget.originalPresentation == ImageAttachmentOriginalPresentation.failed)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.all(prego.spacing.lg),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: prego.colors.bgSurface2,
                            borderRadius: BorderRadius.circular(prego.radius.lg),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(prego.spacing.md),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    context.loc.sessionDetailImageOriginalLoadFailed,
                                    style: prego.textTheme.textSm.regular,
                                  ),
                                ),
                                SizedBox(width: prego.spacing.md),
                                TextButton.icon(
                                  onPressed: widget.onRetryOriginal,
                                  icon: const Icon(Icons.refresh),
                                  label: Text(context.loc.sessionDetailRetryOriginal),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _dismiss,
      },
      // The viewer holds no focusable chrome of its own, so claim focus for the
      // route to give Escape somewhere to land.
      child: Focus(autofocus: true, child: viewer),
    );
  }
}
