import "package:flutter/foundation.dart";
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

    // Android deliberately has no native branch: a hybrid-composition platform
    // view idles Flutter beautifully on a static screen, but wrecks scroll
    // performance wherever a spinner shares the screen with a scrolling list
    // (measured on-device, 2026-08-31), so the animated Flutter arc stays.
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
      TargetPlatform.android || TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.windows => null,
    };

    if (nativeView == null) {
      return _indicator(value: null);
    }
    // Native views consume creationParams only at creation, so a colour change
    // (a theme switch while a spinner is visible) must recreate the view.
    return KeyedSubtree(key: ValueKey(color.toARGB32()), child: nativeView);
  }

  Widget _indicator({required double? value}) {
    // The approved wrapper owns the Flutter fallback for platforms without a
    // native renderer and for static reduced-motion states.
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
