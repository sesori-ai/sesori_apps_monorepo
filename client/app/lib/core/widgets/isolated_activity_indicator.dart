import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";

import "../extensions/build_context_x.dart";

/// A smooth activity indicator that animates outside Flutter on mobile.
class IsolatedActivityIndicator extends StatelessWidget {
  static const _nativeViewType = "sesori/native-activity-indicator";
  static const _staticArcSweep = 0.75;

  final double strokeWidth;
  final Color color;

  const IsolatedActivityIndicator({
    super.key,
    required this.strokeWidth,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final animationsEnabled = !context.isReducedMotion && TickerMode.valuesOf(context).enabled;

    return Semantics(
      role: SemanticsRole.loadingSpinner,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: animationsEnabled ? _animatedIndicator() : _indicator(value: _staticArcSweep),
        ),
      ),
    );
  }

  Widget _animatedIndicator() {
    if (kIsWeb) {
      return _indicator(value: null);
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => UiKitView(
        viewType: _nativeViewType,
        creationParams: color.toARGB32(),
        creationParamsCodec: const StandardMessageCodec(),
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      ),
      TargetPlatform.android => AndroidView(
        viewType: _nativeViewType,
        creationParams: color.toARGB32(),
        creationParamsCodec: const StandardMessageCodec(),
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      ),
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => _indicator(value: null),
    };
  }

  CircularProgressIndicator _indicator({required double? value}) {
    return CircularProgressIndicator(
      value: value,
      strokeWidth: strokeWidth,
      strokeCap: StrokeCap.round,
      color: color,
      backgroundColor: Colors.transparent,
    );
  }
}
