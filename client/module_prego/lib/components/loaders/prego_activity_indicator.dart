import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";

/// A Prego activity indicator that animates outside Flutter where supported.
class const PregoActivityIndicator({
  super.key,
  required final Color color,
}) extends StatelessWidget {
  static const _nativeViewType = "sesori/native-activity-indicator";
  static const _defaultDimension = 36.0;
  static const _staticArcSweep = 0.75;
  static const _fallbackStrokeWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final animationsEnabled = !reducedMotion && TickerMode.valuesOf(context).enabled;

    return Semantics(
      role: SemanticsRole.loadingSpinner,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: _defaultDimension,
            child: animationsEnabled ? _animatedIndicator() : _indicator(value: _staticArcSweep),
          ),
        ),
      ),
    );
  }

  Widget _animatedIndicator() {
    if (kIsWeb) {
      return _indicator(value: null);
    }

    final nativeView = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => UiKitView(
        viewType: _nativeViewType,
        creationParams: color.toARGB32(),
        creationParamsCodec: const StandardMessageCodec(),
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      ),
      TargetPlatform.macOS => AppKitView(
        viewType: _nativeViewType,
        creationParams: color.toARGB32(),
        creationParamsCodec: const StandardMessageCodec(),
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      ),
      TargetPlatform.android => _androidIndicator(),
      TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.windows => null,
    };

    return nativeView ?? _indicator(value: null);
  }

  /// Forced hybrid composition, not the default texture-layer mode: a texture
  /// layer schedules a Flutter frame for every native spinner frame, keeping
  /// the whole raster pipeline hot, while a real Android view animates on
  /// RenderThread and lets an otherwise-static Flutter scene schedule nothing.
  Widget _androidIndicator() {
    // PlatformViewLink calls onCreatePlatformView before surfaceFactory, so the
    // typed controller can be captured instead of downcasting the surface
    // callback's PlatformViewController parameter.
    late final ExpensiveAndroidViewController viewController;
    return PlatformViewLink(
      viewType: _nativeViewType,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: viewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        );
      },
      onCreatePlatformView: (params) {
        viewController = PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: params.viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: color.toARGB32(),
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        );
        viewController
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
        return viewController;
      },
    );
  }

  Widget _indicator({required double? value}) {
    // The approved wrapper owns the Flutter fallback on non-iOS platforms.
    // ignore: no_slop_linter/avoid_flutter_spinners
    return CircularProgressIndicator(
      value: value,
      strokeWidth: _fallbackStrokeWidth,
      strokeCap: StrokeCap.round,
      color: color,
      backgroundColor: Colors.transparent,
    );
  }
}
