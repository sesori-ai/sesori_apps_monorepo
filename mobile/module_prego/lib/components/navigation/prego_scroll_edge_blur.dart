import "dart:ui" as ui;

import "package:flutter/material.dart";

/// A progressive ("graduated") blur for the top scroll edge — the iOS-26 frosted
/// navigation look, where content directly under the bar is blurred and the
/// blur releases smoothly into clear content a little below the bar.
///
/// Pairs with [PregoGlassScaffold]'s scroll-edge fade: the fade dissolves the
/// scrolling content's colour into the page background while this blurs it, so
/// content passing behind the transparent bar both softens and dissolves rather
/// than sliding under a hard edge.
///
/// ## Why bands instead of a masked [BackdropFilter]
///
/// A single [BackdropFilter] blurs uniformly and leaves a hard line where the
/// blur stops. The obvious fix — fading it out with a [ShaderMask] — is unsafe
/// around glass: the `saveLayer` that ShaderMask creates leaves the backdrop
/// empty under Impeller, so the filter (and any glass behind it) renders as
/// opaque black. `liquid_glass_widgets` documents this exact pitfall for its own
/// scroll-edge fade. Instead this stacks several clipped [BackdropFilter] bands
/// whose blur steps down from [sigma] to zero; each band samples the real
/// content beneath it, so no `saveLayer` ever wraps a backdrop filter and glass
/// keeps rendering. The whole thing is wrapped in [IgnorePointer] so it never
/// intercepts taps on the content scrolling beneath it.
class PregoScrollEdgeBlur extends StatelessWidget {
  const PregoScrollEdgeBlur({
    super.key,
    required this.height,
    required this.plateauHeight,
    this.sigma = 1,
    this.bands = 5,
  });

  /// Total height of the blur zone, measured from the very top of the bar.
  /// Typically the safe-area top + bar height + the scaffold's fade extent, so
  /// the blur releases exactly where the scroll-edge fade fades out.
  final double height;

  /// Height of the fully-blurred top region (the status bar + nav bar). The
  /// blur holds at [sigma] across this region, then ramps to zero over the
  /// remaining [height] − [plateauHeight] so the frost releases below the bar.
  final double plateauHeight;

  /// Peak blur strength, in logical pixels, applied across the [plateauHeight]
  /// region (and the start of the release ramp).
  final double sigma;

  /// Number of bands the release ramp is split into. More bands → smoother
  /// ramp at a small per-band cost; the default five hides the steps under the
  /// fade.
  final int bands;

  /// Bands weaker than this contribute no visible blur and are skipped, so the
  /// tail of the ramp doesn't spend backdrop filters on imperceptible blur.
  static const double _minSigma = 0.3;

  @override
  Widget build(BuildContext context) {
    final rampHeight = (height - plateauHeight).clamp(0.0, height);
    final bandHeight = bands > 0 ? rampHeight / bands : 0.0;

    final layers = <Widget>[
      // Uniform frost across the status bar + nav bar.
      if (plateauHeight > 0) Positioned(top: 0, left: 0, right: 0, height: plateauHeight, child: _blur(sigma)),
    ];

    // Release ramp: blur eases from [sigma] (flush with the plateau) to zero at
    // the bottom, so content sharpens smoothly below the bar instead of meeting
    // a hard frosted edge.
    for (var i = 0; i < bands; i++) {
      // p: 0 at the top of the ramp (flush with the plateau) → 1 at the bottom.
      // With a single band there is no ramp to walk, so anchor it at the top
      // (p = 0) — a full-strength band that extends the plateau frost across the
      // ramp — rather than at p = 1, which would zero its blur and drop it
      // entirely, leaving an abrupt cutoff below the plateau.
      final p = bands > 1 ? i / (bands - 1) : 0.0;
      // Quadratic ease-out: holds the frost briefly, then releases with a long
      // gentle tail — mirroring the soft fade curve it sits over.
      final bandSigma = sigma * (1 - p) * (1 - p);
      if (bandSigma < _minSigma) continue;
      layers.add(
        Positioned(
          top: plateauHeight + i * bandHeight,
          left: 0,
          right: 0,
          // Overlap each slice by a hair so the steps never show a seam.
          height: bandHeight + 1,
          child: _blur(bandSigma),
        ),
      );
    }

    return IgnorePointer(
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(fit: StackFit.expand, children: layers),
      ),
    );
  }

  /// A single clipped backdrop blur band. [ClipRect] (not a `saveLayer`) bounds
  /// the filter to its slice, keeping it safe to compose with glass.
  Widget _blur(double sigma) => ClipRect(
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: const SizedBox.expand(),
    ),
  );
}
