import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";

/// A Prego activity indicator that animates outside Flutter where supported.
class PregoActivityIndicator extends StatelessWidget {
  static const _nativeViewType = "sesori/native-activity-indicator";
  static const _defaultDimension = 36.0;
  static const _staticArcSweep = 0.75;
  static const _fallbackStrokeWidth = 2.0;

  final Color color;

  const PregoActivityIndicator({
    super.key,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final animationsEnabled = !reducedMotion && TickerMode.valuesOf(context).enabled;

    return Semantics(
      role: SemanticsRole.loadingSpinner,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: animationsEnabled ? _animatedIndicator(context: context) : _indicator(value: _staticArcSweep),
        ),
      ),
    );
  }

  Widget _animatedIndicator({required BuildContext context}) {
    if (kIsWeb) {
      return _indicator(value: null);
    }

    final nativeView = switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidIndicator(context: context),
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
      TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.windows => null,
    };

    return nativeView == null
        ? _indicator(value: null)
        : SizedBox.square(dimension: _defaultDimension, child: nativeView);
  }

  Widget _androidIndicator({required BuildContext context}) {
    final layoutDirection = Directionality.of(context);

    return PlatformViewLink(
      viewType: _nativeViewType,
      surfaceFactory: (context, controller) {
        if (controller is! AndroidViewController) {
          throw StateError("Expected an Android platform view controller");
        }
        return AndroidViewSurface(
          controller: controller,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        );
      },
      onCreatePlatformView: (params) {
        return PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: _nativeViewType,
            layoutDirection: layoutDirection,
            creationParams: color.toARGB32(),
            creationParamsCodec: const StandardMessageCodec(),
            onFocus: () => params.onFocusChanged(true),
          )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }

  CircularProgressIndicator _indicator({required double? value}) {
    return CircularProgressIndicator(
      value: value,
      strokeWidth: _fallbackStrokeWidth,
      strokeCap: StrokeCap.round,
      color: color,
      backgroundColor: Colors.transparent,
    );
  }
}
