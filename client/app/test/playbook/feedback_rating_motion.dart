import "dart:math" as math;

import "package:flutter_svg/flutter_svg.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

// Figma NILKXLD9cwuWHhLnGqPqeJ / 5527:8368, exported 2026-09-08.
// All ten animated nodes share the sheet's timeline. Keyframes retain Figma's
// normalized 2s source; the sheet preserves the opening and shortens the tail.
// Geometry is in the original 370×190 hero coordinates, scaled as one unit.
// Static image treatments are baked into two 3× exports; vector art is retained.

class const FeedbackRatingHero({super.key, required final Animation<double> animation}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: AspectRatio(
          aspectRatio: 370 / 190,
          child: FittedBox(
            child: SizedBox(
              width: 370,
              height: 190,
              // The entire Figma illustration is reflected horizontally.
              child: Transform.scale(
                scaleX: -1,
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) => ShaderMask(
                    blendMode: BlendMode.softLight,
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        const Color(0xfffd65dc).withValues(alpha: _glowOpacity.transform(animation.value)),
                        const Color(0x00ffffff),
                      ],
                    ).createShader(bounds),
                    child: child,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Image.asset("assets/images/feedback_rating_background.png", fit: BoxFit.fill),
                      ),
                      _HeroLayer(
                        animation: animation,
                        bounds: const Rect.fromLTWH(241.922, 81, 128.078, 113.374),
                        offset: _doodleLeftOffset,
                        scale: _doodleLeftScale,
                        rotation: _doodleLeftRotation,
                        baseRotation: -0.348,
                        // The exported group already carries its 90% opacity.
                        opacity: ConstantTween(1),
                        child: const _HeroArt(
                          asset: "left_doodle",
                          width: 106.516,
                          height: 81.984,
                          angle: -0.348,
                          outset: EdgeInsets.fromLTRB(0.0038, 0.0293, 0.0552, 0.0185),
                        ),
                      ),
                      _HeroLayer(
                        animation: animation,
                        bounds: const Rect.fromLTWH(35, 85, 26.55, 25.2),
                        offset: _floating1Offset,
                        scale: _floating1Scale,
                        rotation: ConstantTween(0),
                        baseRotation: 0,
                        opacity: _floating1Opacity,
                        child: const _HeroArt(
                          asset: "floating_1",
                          width: 26.55,
                          height: 25.2,
                          angle: 0,
                          outset: EdgeInsets.fromLTRB(0.0696, 0.0887, 0.0922, 0.0113),
                        ),
                      ),
                      _HeroLayer(
                        animation: animation,
                        bounds: const Rect.fromLTWH(125, 49.847, 48.722, 48.238),
                        offset: _floating2Offset,
                        scale: _floating2Scale,
                        rotation: ConstantTween(0),
                        baseRotation: 0,
                        opacity: _floating2Opacity,
                        child: const _HeroArt(
                          asset: "floating_2",
                          width: 35.811,
                          height: 33.975,
                          angle: -0.598,
                          outset: EdgeInsets.fromLTRB(0.0706, 0.0724, 0.0832, 0.0439),
                        ),
                      ),
                      _HeroLayer(
                        animation: animation,
                        bounds: const Rect.fromLTWH(215, 80, 23.6, 22.4),
                        offset: _floating3Offset,
                        scale: _floating3Scale,
                        rotation: ConstantTween(0),
                        baseRotation: 0,
                        opacity: _floating3Opacity,
                        child: const _HeroArt(
                          asset: "floating_3",
                          width: 23.6,
                          height: 22.4,
                          angle: 0,
                          outset: EdgeInsets.fromLTRB(0.0696, 0.0887, 0.0922, 0.0113),
                        ),
                      ),
                      _HeroLayer(
                        animation: animation,
                        bounds: const Rect.fromLTWH(305, 49.684, 37.029, 36.661),
                        offset: _floating4Offset,
                        scale: _floating4Scale,
                        rotation: ConstantTween(0),
                        baseRotation: 0,
                        opacity: _floating4Opacity,
                        child: const _HeroArt(
                          asset: "floating_4",
                          width: 27.217,
                          height: 25.821,
                          angle: -0.598,
                          outset: EdgeInsets.fromLTRB(0.0706, 0.0724, 0.0832, 0.0439),
                        ),
                      ),
                      // The rising hearts pass behind the phone, as in Figma.
                      Positioned.fill(child: Image.asset("assets/images/feedback_rating_phone.png", fit: BoxFit.fill)),
                      _HeroLayer(
                        animation: animation,
                        bounds: const Rect.fromLTWH(43.555, -6, 97.445, 96.476),
                        offset: _heart1Offset,
                        scale: _heart1Scale,
                        rotation: _heart1Rotation,
                        baseRotation: -0.598,
                        opacity: _heart1Opacity,
                        child: const _HeroArt(
                          asset: "heart_1",
                          width: 71.623,
                          height: 67.951,
                          angle: -0.598,
                          outset: EdgeInsets.fromLTRB(0.0706, 0.0724, 0.0832, 0.0439),
                        ),
                      ),
                      _HeroLayer(
                        animation: animation,
                        bounds: const Rect.fromLTWH(247, 39, 59, 56),
                        offset: _heart2Offset,
                        scale: _heart2Scale,
                        rotation: _heart2Rotation,
                        baseRotation: 0,
                        opacity: _heart2Opacity,
                        child: const _HeroArt(
                          asset: "heart_2",
                          width: 59,
                          height: 56,
                          angle: 0,
                          outset: EdgeInsets.fromLTRB(0.0696, 0.0887, 0.0922, 0.0113),
                        ),
                      ),
                      _HeroLayer(
                        animation: animation,
                        bounds: const Rect.fromLTWH(23.7, 107, 87.3, 81.486),
                        offset: _doodleRightOffset,
                        scale: _doodleRightScale,
                        rotation: _doodleRightRotation,
                        baseRotation: -0.332,
                        opacity: ConstantTween(1),
                        child: const _HeroArt(
                          asset: "right_doodle",
                          width: 71.074,
                          height: 61.687,
                          angle: -0.332,
                          outset: EdgeInsets.fromLTRB(0.0063, 0.0555, 0.0463, 0.02),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class const _HeroArt({
  required final String asset,
  required final double width,
  required final double height,
  required final double angle,
  required final EdgeInsets outset,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Transform.rotate(
      angle: angle,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -width * outset.left,
              top: -height * outset.top,
              width: width * (1 + outset.horizontal),
              height: height * (1 + outset.vertical),
              child: SvgPicture.asset("assets/images/feedback_rating_$asset.svg", fit: BoxFit.fill),
            ),
          ],
        ),
      ),
    ),
  );
}

class const _HeroLayer({
  required final Animation<double> animation,
  required final Rect bounds,
  required final Animatable<Offset> offset,
  required final Animatable<Offset> scale,
  required final Animatable<double> rotation,
  required final double baseRotation,
  required final Animatable<double> opacity,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Positioned.fromRect(
    rect: bounds,
    child: AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final position = offset.transform(t);
        final size = scale.transform(t);
        return Opacity(
          opacity: opacity.transform(t).clamp(0, 1),
          child: Transform(
            alignment: Alignment.center,
            // Figma exports absolute angles. The static art already has its
            // base rotation, so only the animated difference belongs here.
            transform: Matrix4.identity()
              ..translateByDouble(position.dx, position.dy, 0, 1)
              ..rotateZ(rotation.transform(t) - baseRotation)
              ..scaleByDouble(size.dx, size.dy, 1, 1),
            child: child,
          ),
        );
      },
      child: child,
    ),
  );
}

/// Light mode starts with Primary Alt's colors; dark mode keeps Figma's white.
/// A stock TextButton retains focus/keyboard/semantics without adding Prego's
/// separate iOS press spring on top of the authored celebration.
class const FeedbackLoveButton({
  super.key,
  required final Animation<double> animation,
  required final VoidCallback? onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final background = _loveColor(restColor: isLight ? prego.colors.fgPrimary : const Color(0xfffcfcfc));
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = animation.value;
          final scale = _loveScale.transform(t);
          // The first authored color segment blends Primary Alt into pink.
          // Keep its label and border in sync, without a white flash on tap.
          final colorProgress = _loveTint.transform(t);
          return Opacity(
            opacity: _loveOpacity.transform(t),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateZ(_loveRotation.transform(t))
                ..scaleByDouble(scale.dx, scale.dy, 1, 1),
              child: TextButton(
                key: const ValueKey("feedback-love"),
                onPressed: onPressed,
                style: ButtonStyle(
                  animationDuration: Duration.zero,
                  minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 52)),
                  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  backgroundColor: WidgetStatePropertyAll(background.transform(t)),
                  foregroundColor: WidgetStatePropertyAll(
                    isLight ? Color.lerp(prego.colors.textPrimaryOnWhite, Colors.black, colorProgress) : Colors.black,
                  ),
                  textStyle: WidgetStatePropertyAll(prego.textTheme.textMd.bold),
                  shape: WidgetStatePropertyAll(
                    StadiumBorder(
                      side: BorderSide(
                        color: isLight
                            ? Color.lerp(prego.colors.alphaWhite10, prego.colors.borderSecondary, colorProgress)!
                            : prego.colors.alphaWhite10,
                        width: 2,
                      ),
                    ),
                  ),
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.focused) || states.contains(WidgetState.pressed)
                        ? Colors.black.withValues(alpha: 0.08)
                        : Colors.transparent,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text("Yes, love it!"),
              ),
            ),
          );
        },
      ),
    );
  }
}

// CSS easing names do not use Flutter's *Cubic variants.
const _easeIn = Cubic(0.42, 0, 1, 1);
const _easeOut = Cubic(0, 0, 0.58, 1);
const _easeInOut = Cubic(0.42, 0, 0.58, 1);

typedef _Keyframe<T> = ({double at, T value, Curve curve});

Animatable<T> _track<T>({
  required List<_Keyframe<T>> keys,
  required Tween<T> Function({required T begin, required T end}) tween,
}) => TweenSequence<T>([
  for (var i = 0; i < keys.length - 1; i++)
    TweenSequenceItem(
      tween: tween(begin: keys[i].value, end: keys[i + 1].value).chain(CurveTween(curve: keys[i].curve)),
      weight: keys[i + 1].at - keys[i].at,
    ),
]);

Animatable<double> _scalar({required List<_Keyframe<double>> keys}) => _track<double>(
  keys: keys,
  tween: ({required begin, required end}) => Tween<double>(begin: begin, end: end),
);
Animatable<Offset> _vector({required List<_Keyframe<Offset>> keys}) => _track<Offset>(
  keys: keys,
  tween: ({required begin, required end}) => Tween<Offset>(begin: begin, end: end),
);
Animatable<Color?> _color({required List<_Keyframe<Color>> keys}) => _track<Color?>(
  keys: keys,
  tween: ({required begin, required end}) => ColorTween(begin: begin, end: end),
);

// Figma's linear(...) exports are sampled spring curves, including overshoot.
// Linear interpolation between the supplied samples preserves those curves.
class const _SampledCurve({required final List<double> samples}) extends Curve {
  @override
  double transformInternal(double t) {
    final position = t * (samples.length - 1);
    final index = math.min(position.floor(), samples.length - 2);
    return samples[index] + (samples[index + 1] - samples[index]) * (position - index);
  }
}

const _spring1 = _SampledCurve(
  samples: [
    0,
    0.0147,
    0.0529,
    0.1072,
    0.1716,
    0.2415,
    0.3136,
    0.3852,
    0.4545,
    0.5201,
    0.5812,
    0.6374,
    0.6884,
    0.7342,
    0.7749,
    0.8108,
    0.8422,
    0.8695,
    0.893,
    0.913,
    0.93,
    0.9444,
    0.9564,
    0.9663,
    0.9745,
    0.9811,
    0.9865,
    0.9908,
    0.9941,
    0.9968,
    0.9988,
    1.0002,
    1.0013,
    1.0021,
    1.0025,
    1.0028,
    1.0029,
    1.003,
    1.0029,
    1.0027,
    1.0026,
    1.0024,
    1.0022,
    1.0019,
    1.0017,
    1.0015,
    1.0013,
    1.0012,
    1.001,
    1.0009,
    1.0007,
  ],
);
const _spring2 = _SampledCurve(
  samples: [
    0,
    0.0169,
    0.061,
    0.1236,
    0.1977,
    0.2779,
    0.36,
    0.4408,
    0.5181,
    0.5903,
    0.6564,
    0.716,
    0.7688,
    0.815,
    0.8548,
    0.8887,
    0.9171,
    0.9407,
    0.9598,
    0.9752,
    0.9872,
    0.9965,
    1.0034,
    1.0083,
    1.0117,
    1.0138,
    1.0148,
    1.0152,
    1.0149,
    1.0142,
    1.0133,
    1.0122,
    1.011,
    1.0097,
    1.0085,
    1.0073,
    1.0062,
    1.0052,
    1.0043,
    1.0035,
    1.0028,
    1.0022,
    1.0017,
    1.0013,
    1.0009,
    1.0006,
    1.0004,
    1.0002,
    1.0001,
    0.9999,
    0.9999,
  ],
);
const _spring3 = _SampledCurve(
  samples: [
    0,
    0.0242,
    0.0871,
    0.1757,
    0.2793,
    0.3892,
    0.4987,
    0.6028,
    0.6982,
    0.7827,
    0.8552,
    0.9156,
    0.9641,
    1.0017,
    1.0295,
    1.0486,
    1.0606,
    1.0666,
    1.068,
    1.0659,
    1.0613,
    1.0551,
    1.048,
    1.0405,
    1.0331,
    1.026,
    1.0197,
    1.014,
    1.0092,
    1.0052,
    1.002,
    0.9996,
    0.9978,
    0.9965,
    0.9958,
    0.9954,
    0.9954,
    0.9955,
    0.9959,
    0.9963,
    0.9968,
    0.9973,
    0.9978,
    0.9983,
    0.9987,
    0.9991,
    0.9994,
    0.9997,
    0.9999,
    1.0001,
    1.0002,
  ],
);
const _spring4 = _SampledCurve(
  samples: [
    0,
    0.0476,
    0.1697,
    0.3363,
    0.5209,
    0.7022,
    0.8645,
    0.998,
    1.0978,
    1.1634,
    1.1975,
    1.205,
    1.192,
    1.1648,
    1.1296,
    1.0915,
    1.0548,
    1.0224,
    0.9962,
    0.977,
    0.9647,
    0.9588,
    0.9581,
    0.9614,
    0.9674,
    0.9748,
    0.9826,
    0.99,
    0.9965,
    1.0016,
    1.0053,
    1.0076,
    1.0086,
    1.0085,
    1.0077,
    1.0064,
    1.0049,
    1.0033,
    1.0018,
    1.0005,
    0.9995,
    0.9988,
    0.9984,
    0.9982,
    0.9983,
    0.9985,
    0.9987,
    0.9991,
    0.9994,
    0.9997,
    0.9999,
  ],
);
// Figma 5528:30782 · Vector container · rotate
final _doodleLeftRotation = _scalar(
  keys: const [
    (at: 0.0, value: -0.348, curve: _easeInOut),
    (at: 0.38633, value: -0.383, curve: _spring1),
    (at: 0.77265, value: -0.348, curve: Curves.linear),
    (at: 1.0, value: -0.348, curve: Curves.linear),
  ],
);

// Figma 5528:30782 · Vector container · translate
final _doodleLeftOffset = _vector(
  keys: const [
    (at: 0.0, value: Offset.zero, curve: _easeInOut),
    (at: 0.25755, value: Offset(1.5, -3), curve: _easeInOut),
    (at: 0.5151, value: Offset(-1, -1), curve: _easeInOut),
    (at: 0.77265, value: Offset(0.5, -2), curve: Curves.linear),
    (at: 1.0, value: Offset(0.5, -2), curve: Curves.linear),
  ],
);

// Figma 5528:30782 · Vector container · scale
final _doodleLeftScale = _vector(
  keys: const [
    (at: 0.0, value: Offset(1, 1), curve: _easeInOut),
    (at: 0.32194, value: Offset(1.03, 1.03), curve: _easeInOut),
    (at: 0.70826, value: Offset(1, 1), curve: Curves.linear),
    (at: 1.0, value: Offset(1, 1), curve: Curves.linear),
  ],
);

// Figma 5528:30804 · Floating Heart · opacity
final _floating1Opacity = _scalar(
  keys: const [
    (at: 0.0, value: 0, curve: Curves.linear),
    (at: 0.05, value: 0, curve: _easeOut),
    (at: 0.148, value: 0.75, curve: Cubic(0.5, 0, 0.5, 1)),
    (at: 0.67722, value: 0.7, curve: _easeIn),
    (at: 0.83402, value: 0, curve: Curves.linear),
    (at: 1.0, value: 0, curve: Curves.linear),
  ],
);

// Figma 5528:30804 · Floating Heart · translate
final _floating1Offset = _vector(
  keys: const [
    (at: 0.0, value: Offset(0, 165), curve: Curves.linear),
    (at: 0.05, value: Offset(0, 165), curve: Curves.linear),
    (at: 0.1, value: Offset(-1.065, 97.283), curve: Curves.linear),
    (at: 0.15, value: Offset(-4.348, 41.737), curve: Curves.linear),
    (at: 0.2, value: Offset(-8.895, -2.604), curve: Curves.linear),
    (at: 0.25, value: Offset(-12.517, -37.125), curve: Curves.linear),
    (at: 0.3, value: Offset(-13.969, -63.386), curve: Curves.linear),
    (at: 0.35, value: Offset(-12.769, -82.932), curve: Curves.linear),
    (at: 0.4, value: Offset(-7.771, -97.16), curve: Curves.linear),
    (at: 0.45, value: Offset(-0.105, -107.27), curve: Curves.linear),
    (at: 0.5, value: Offset(6.622, -114.25), curve: Curves.linear),
    (at: 0.55, value: Offset(9.787, -118.895), curve: Curves.linear),
    (at: 0.6, value: Offset(9.526, -121.837), curve: Curves.linear),
    (at: 0.65, value: Offset(6.803, -123.572), curve: Curves.linear),
    (at: 0.7, value: Offset(2.076, -124.486), curve: Curves.linear),
    (at: 0.75, value: Offset(-2.686, -124.882), curve: Curves.linear),
    (at: 0.8, value: Offset(-5.481, -124.993), curve: Curves.linear),
    (at: 0.85, value: Offset(-6, -125), curve: Curves.linear),
    (at: 1.0, value: Offset(-6, -125), curve: Curves.linear),
  ],
);

// Figma 5528:30804 · Floating Heart · scale
final _floating1Scale = _vector(
  keys: const [
    (at: 0.0, value: Offset(0.5, 0.5), curve: Curves.linear),
    (at: 0.05, value: Offset(0.5, 0.5), curve: Cubic(0.45, 1.45, 0.8, 1)),
    (at: 0.1872, value: Offset(1.05, 1.05), curve: _easeOut),
    (at: 0.24601, value: Offset(1, 1), curve: Curves.linear),
    (at: 1.0, value: Offset(1, 1), curve: Curves.linear),
  ],
);

// Figma 5528:30822 · Floating Heart · opacity
final _floating2Opacity = _scalar(
  keys: const [
    (at: 0.0, value: 0, curve: Curves.linear),
    (at: 0.15, value: 0, curve: _easeOut),
    (at: 0.248, value: 0.75, curve: Cubic(0.5, 0, 0.5, 1)),
    (at: 0.77722, value: 0.7, curve: _easeIn),
    (at: 0.93402, value: 0, curve: Curves.linear),
    (at: 1.0, value: 0, curve: Curves.linear),
  ],
);

// Figma 5528:30822 · Floating Heart · translate
final _floating2Offset = _vector(
  keys: const [
    (at: 0.0, value: Offset(0, 180), curve: Curves.linear),
    (at: 0.15, value: Offset(0, 180), curve: Curves.linear),
    (at: 0.2, value: Offset(1.065, 112.283), curve: Curves.linear),
    (at: 0.25, value: Offset(4.348, 56.737), curve: Curves.linear),
    (at: 0.3, value: Offset(8.895, 12.396), curve: Curves.linear),
    (at: 0.35, value: Offset(12.517, -22.125), curve: Curves.linear),
    (at: 0.4, value: Offset(13.969, -48.386), curve: Curves.linear),
    (at: 0.45, value: Offset(12.769, -67.932), curve: Curves.linear),
    (at: 0.5, value: Offset(7.771, -82.16), curve: Curves.linear),
    (at: 0.55, value: Offset(0.105, -92.27), curve: Curves.linear),
    (at: 0.6, value: Offset(-6.622, -99.25), curve: Curves.linear),
    (at: 0.65, value: Offset(-9.787, -103.895), curve: Curves.linear),
    (at: 0.7, value: Offset(-9.526, -106.837), curve: Curves.linear),
    (at: 0.75, value: Offset(-6.803, -108.572), curve: Curves.linear),
    (at: 0.8, value: Offset(-2.076, -109.486), curve: Curves.linear),
    (at: 0.85, value: Offset(2.686, -109.882), curve: Curves.linear),
    (at: 0.9, value: Offset(5.481, -109.993), curve: Curves.linear),
    (at: 0.95, value: Offset(6, -110), curve: Curves.linear),
    (at: 1.0, value: Offset(6, -110), curve: Curves.linear),
  ],
);

// Figma 5528:30822 · Floating Heart · scale
final _floating2Scale = _vector(
  keys: const [
    (at: 0.0, value: Offset(0.5, 0.5), curve: Curves.linear),
    (at: 0.15, value: Offset(0.5, 0.5), curve: Cubic(0.45, 1.45, 0.8, 1)),
    (at: 0.2872, value: Offset(1.05, 1.05), curve: _easeOut),
    (at: 0.34601, value: Offset(1, 1), curve: Curves.linear),
    (at: 1.0, value: Offset(1, 1), curve: Curves.linear),
  ],
);

// Figma 5528:30840 · Floating Heart · opacity
final _floating3Opacity = _scalar(
  keys: const [
    (at: 0.0, value: 0, curve: Curves.linear),
    (at: 0.1, value: 0, curve: _easeOut),
    (at: 0.198, value: 0.75, curve: Cubic(0.5, 0, 0.5, 1)),
    (at: 0.72722, value: 0.7, curve: _easeIn),
    (at: 0.88402, value: 0, curve: Curves.linear),
    (at: 1.0, value: 0, curve: Curves.linear),
  ],
);

// Figma 5528:30840 · Floating Heart · translate
final _floating3Offset = _vector(
  keys: const [
    (at: 0.0, value: Offset(0, 170), curve: Curves.linear),
    (at: 0.1, value: Offset(0, 170), curve: Curves.linear),
    (at: 0.15, value: Offset(-1.065, 102.283), curve: Curves.linear),
    (at: 0.2, value: Offset(-4.348, 46.737), curve: Curves.linear),
    (at: 0.25, value: Offset(-8.895, 2.396), curve: Curves.linear),
    (at: 0.3, value: Offset(-12.517, -32.125), curve: Curves.linear),
    (at: 0.35, value: Offset(-13.969, -58.386), curve: Curves.linear),
    (at: 0.4, value: Offset(-12.769, -77.932), curve: Curves.linear),
    (at: 0.45, value: Offset(-7.771, -92.16), curve: Curves.linear),
    (at: 0.5, value: Offset(-0.105, -102.27), curve: Curves.linear),
    (at: 0.55, value: Offset(6.622, -109.25), curve: Curves.linear),
    (at: 0.6, value: Offset(9.787, -113.895), curve: Curves.linear),
    (at: 0.65, value: Offset(9.526, -116.837), curve: Curves.linear),
    (at: 0.7, value: Offset(6.803, -118.572), curve: Curves.linear),
    (at: 0.75, value: Offset(2.076, -119.486), curve: Curves.linear),
    (at: 0.8, value: Offset(-2.686, -119.882), curve: Curves.linear),
    (at: 0.85, value: Offset(-5.481, -119.993), curve: Curves.linear),
    (at: 0.9, value: Offset(-6, -120), curve: Curves.linear),
    (at: 1.0, value: Offset(-6, -120), curve: Curves.linear),
  ],
);

// Figma 5528:30840 · Floating Heart · scale
final _floating3Scale = _vector(
  keys: const [
    (at: 0.0, value: Offset(0.5, 0.5), curve: Curves.linear),
    (at: 0.1, value: Offset(0.5, 0.5), curve: Cubic(0.45, 1.45, 0.8, 1)),
    (at: 0.2372, value: Offset(1.05, 1.05), curve: _easeOut),
    (at: 0.29601, value: Offset(1, 1), curve: Curves.linear),
    (at: 1.0, value: Offset(1, 1), curve: Curves.linear),
  ],
);

// Figma 5528:30858 · Floating Heart · opacity
final _floating4Opacity = _scalar(
  keys: const [
    (at: 0.0, value: 0, curve: Curves.linear),
    (at: 0.225, value: 0, curve: _easeOut),
    (at: 0.323, value: 0.75, curve: Cubic(0.5, 0, 0.5, 1)),
    (at: 0.85222, value: 0.7, curve: _easeIn),
    (at: 1.0, value: 0, curve: Curves.linear),
  ],
);

// Figma 5528:30858 · Floating Heart · translate
final _floating4Offset = _vector(
  keys: const [
    (at: 0.0, value: Offset(0, 185), curve: Curves.linear),
    (at: 0.19999776, value: Offset(0, 185), curve: Curves.linear),
    (at: 0.25000476, value: Offset(0.257, 149.582), curve: Curves.linear),
    (at: 0.30000168, value: Offset(2.447, 88.036), curve: Curves.linear),
    (at: 0.34999859, value: Offset(6.593, 38.245), curve: Curves.linear),
    (at: 0.39999551, value: Offset(10.942, -0.996), curve: Curves.linear),
    (at: 0.45000252, value: Offset(13.525, -31.189), curve: Curves.linear),
    (at: 0.49999943, value: Offset(13.816, -53.907), curve: Curves.linear),
    (at: 0.54999635, value: Offset(10.742, -70.631), curve: Curves.linear),
    (at: 0.60000336, value: Offset(4.08, -82.663), curve: Curves.linear),
    (at: 0.65000027, value: Offset(-3.611, -91.097), curve: Curves.linear),
    (at: 0.69999719, value: Offset(-8.695, -96.821), curve: Curves.linear),
    (at: 0.75000419, value: Offset(-9.975, -100.545), curve: Curves.linear),
    (at: 0.80000111, value: Offset(-8.471, -102.829), curve: Curves.linear),
    (at: 0.84999803, value: Offset(-4.601, -104.111), curve: Curves.linear),
    (at: 0.90000503, value: Offset(0.459, -104.733), curve: Curves.linear),
    (at: 0.95000195, value: Offset(4.39, -104.96), curve: Curves.linear),
    (at: 0.99999887, value: Offset(5.965, -105), curve: Curves.linear),
    (at: 1, value: Offset(5.965004, -105.0), curve: Curves.linear),
  ],
);

// Figma 5528:30858 · Floating Heart · scale
final _floating4Scale = _vector(
  keys: const [
    (at: 0.0, value: Offset(0.5, 0.5), curve: Curves.linear),
    (at: 0.225, value: Offset(0.5, 0.5), curve: Cubic(0.45, 1.45, 0.8, 1)),
    (at: 0.3622, value: Offset(1.05, 1.05), curve: _easeOut),
    (at: 0.42101, value: Offset(1, 1), curve: Curves.linear),
    (at: 1.0, value: Offset(1, 1), curve: Curves.linear),
  ],
);

// Figma 5528:30888 · Vector 4 · opacity
final _heart1Opacity = _scalar(
  keys: const [
    (at: 0.0, value: 1, curve: Cubic(0, 0, 0.2, 1)),
    (at: 0.0784, value: 0.85, curve: Cubic(0.4, 0, 0.2, 1)),
    (at: 0.1568, value: 1, curve: Curves.linear),
    (at: 1.0, value: 1, curve: Curves.linear),
  ],
);

// Figma 5528:30888 · Vector 4 · rotate
final _heart1Rotation = _scalar(
  keys: const [
    (at: 0.0, value: -0.598, curve: Cubic(0.4, 0, 0.2, 1)),
    (at: 0.0588, value: -0.528, curve: _easeInOut),
    (at: 0.1568, value: -0.702, curve: _easeInOut),
    (at: 0.27441, value: -0.545, curve: _spring2),
    (at: 0.43121, value: -0.633, curve: _spring2),
    (at: 0.54881, value: -0.598, curve: Curves.linear),
    (at: 1.0, value: -0.598, curve: Curves.linear),
  ],
);

// Figma 5528:30888 · Vector 4 · translate
final _heart1Offset = _vector(
  keys: const [
    (at: 0.0, value: Offset.zero, curve: Cubic(0, 0, 0.2, 1)),
    (at: 0.03136, value: Offset(1, 3), curve: Cubic(0, 0, 0.2, 1)),
    (at: 0.1372, value: Offset(-10, -16), curve: _spring2),
    (at: 0.31361, value: Offset(-7, -11), curve: _spring2),
    (at: 0.54881, value: Offset(-8, -12), curve: Curves.linear),
    (at: 1.0, value: Offset(-8, -12), curve: Curves.linear),
  ],
);

// Figma 5528:30888 · Vector 4 · scale
final _heart1Scale = _vector(
  keys: const [
    (at: 0.0, value: Offset(1, 1), curve: Cubic(0, 0, 0.2, 1)),
    (at: 0.03136, value: Offset(0.88, 0.92), curve: Cubic(0, 0, 0.2, 1)),
    (at: 0.1176, value: Offset(1.38, 1.42), curve: _spring3),
    (at: 0.23521, value: Offset(1.12, 1.1), curve: _spring2),
    (at: 0.39201, value: Offset(1.2, 1.18), curve: _spring2),
    (at: 0.54881, value: Offset(1.15, 1.15), curve: Curves.linear),
    (at: 1.0, value: Offset(1.15, 1.15), curve: Curves.linear),
  ],
);

// Figma 5528:30913 · Vector 5 · opacity
final _heart2Opacity = _scalar(
  keys: const [
    (at: 0.0, value: 0.9, curve: Curves.linear),
    (at: 0.03, value: 0.9, curve: Cubic(0, 0, 0.2, 1)),
    (at: 0.10448, value: 0.8, curve: Cubic(0.4, 0, 0.2, 1)),
    (at: 0.20248, value: 0.95, curve: Curves.linear),
    (at: 1.0, value: 0.95, curve: Curves.linear),
  ],
);

// Figma 5528:30913 · Vector 5 · rotate
final _heart2Rotation = _scalar(
  keys: const [
    (at: 0.0, value: 0, curve: Curves.linear),
    (at: 0.03, value: 0, curve: Cubic(0.4, 0, 0.2, 1)),
    (at: 0.08488, value: -0.087, curve: _easeInOut),
    (at: 0.18288, value: 0.07, curve: _easeInOut),
    (at: 0.30049, value: -0.052, curve: _spring2),
    (at: 0.45729, value: 0.026, curve: _spring2),
    (at: 0.59449, value: 0, curve: Curves.linear),
    (at: 1.0, value: 0, curve: Curves.linear),
  ],
);

// Figma 5528:30913 · Vector 5 · translate
final _heart2Offset = _vector(
  keys: const [
    (at: 0.0, value: Offset.zero, curve: Curves.linear),
    (at: 0.03, value: Offset.zero, curve: Cubic(0, 0, 0.2, 1)),
    (at: 0.06136, value: Offset(-1, 2), curve: Cubic(0, 0, 0.2, 1)),
    (at: 0.16328, value: Offset(8, -12), curve: _spring2),
    (at: 0.33969, value: Offset(5, -8), curve: _spring2),
    (at: 0.59449, value: Offset(6, -9), curve: Curves.linear),
    (at: 1.0, value: Offset(6, -9), curve: Curves.linear),
  ],
);

// Figma 5528:30913 · Vector 5 · scale
final _heart2Scale = _vector(
  keys: const [
    (at: 0.0, value: Offset(1, 1), curve: Curves.linear),
    (at: 0.03, value: Offset(1, 1), curve: Cubic(0, 0, 0.2, 1)),
    (at: 0.06136, value: Offset(0.9, 0.94), curve: Cubic(0, 0, 0.2, 1)),
    (at: 0.15544, value: Offset(1.35, 1.38), curve: _spring3),
    (at: 0.26129, value: Offset(1.08, 1.1), curve: _spring2),
    (at: 0.41809, value: Offset(1.18, 1.16), curve: _spring2),
    (at: 0.59449, value: Offset(1.12, 1.12), curve: Curves.linear),
    (at: 1.0, value: Offset(1.12, 1.12), curve: Curves.linear),
  ],
);

// Figma 5528:30927 · Icon container · rotate
final _doodleRightRotation = _scalar(
  keys: const [
    (at: 0.0, value: -0.332, curve: Curves.linear),
    (at: 0.075, value: -0.332, curve: _easeInOut),
    (at: 0.52581, value: -0.306, curve: _spring1),
    (at: 0.97662, value: -0.332, curve: Curves.linear),
    (at: 1.0, value: -0.332, curve: Curves.linear),
  ],
);

// Figma 5528:30927 · Icon container · translate
final _doodleRightOffset = _vector(
  keys: const [
    (at: 0.0, value: Offset.zero, curve: Curves.linear),
    (at: 0.075, value: Offset.zero, curve: _easeInOut),
    (at: 0.36901, value: Offset(-2, -2.5), curve: _easeInOut),
    (at: 0.68262, value: Offset(1, -0.5), curve: _easeInOut),
    (at: 0.97662, value: Offset(-0.5, -1.5), curve: Curves.linear),
    (at: 1.0, value: Offset(-0.5, -1.5), curve: Curves.linear),
  ],
);

// Figma 5528:30927 · Icon container · scale
final _doodleRightScale = _vector(
  keys: const [
    (at: 0.0, value: Offset(1, 1), curve: Curves.linear),
    (at: 0.075, value: Offset(1, 1), curve: _easeInOut),
    (at: 0.44741, value: Offset(1.025, 1.025), curve: _easeInOut),
    (at: 0.91782, value: Offset(1, 1), curve: Curves.linear),
    (at: 1.0, value: Offset(1, 1), curve: Curves.linear),
  ],
);

// Figma 5528:30934 · Rectangle 2 · opacity
final _glowOpacity = _scalar(
  keys: const [
    (at: 0.0, value: 0, curve: Cubic(0.4, 0, 0.2, 1)),
    (at: 0.0899, value: 1, curve: Cubic(0.4, 0, 0.6, 1)),
    (at: 0.33713, value: 0, curve: Curves.linear),
    (at: 1.0, value: 0, curve: Curves.linear),
  ],
);

// Figma 5528:1783 · pregoButtonsSolid · opacity
final _loveOpacity = _scalar(
  keys: const [
    (at: 0.0, value: 1, curve: _easeOut),
    (at: 0.02468, value: 0.75, curve: _easeOut),
    (at: 0.11105, value: 1, curve: Curves.linear),
    (at: 1.0, value: 1, curve: Curves.linear),
  ],
);

// Figma 5528:1783 · pregoButtonsSolid · rotate
final _loveRotation = _scalar(
  keys: const [
    (at: 0.0, value: 0, curve: _easeOut),
    (at: 0.04936, value: 0.019, curve: _easeOut),
    (at: 0.12339, value: -0.035, curve: _easeOut),
    (at: 0.19743, value: 0.026, curve: _easeOut),
    (at: 0.30848, value: 0, curve: Curves.linear),
    (at: 1.0, value: 0, curve: Curves.linear),
  ],
);

// Figma 5528:1783 · pregoButtonsSolid · background-color
const _lovePinkAt = 0.04936;
Animatable<Color?> _loveColor({required Color restColor}) => _color(
  keys: [
    (at: 0.0, value: restColor, curve: _easeOut),
    (at: _lovePinkAt, value: const Color(0xffff54a3), curve: _easeInOut),
    (at: 0.18509, value: const Color(0xffffbfd9), curve: _easeInOut),
    (at: 0.40103, value: restColor, curve: Curves.linear),
    (at: 1.0, value: restColor, curve: Curves.linear),
  ],
);

// Label and border follow the same pink entrance and return to Primary Alt.
final _loveTint = _scalar(
  keys: const [
    (at: 0, value: 0, curve: _easeOut),
    (at: _lovePinkAt, value: 1, curve: _easeInOut),
    (at: 0.18509, value: 1, curve: _easeInOut),
    (at: 0.40103, value: 0, curve: Curves.linear),
    (at: 1, value: 0, curve: Curves.linear),
  ],
);

// Figma 5528:1783 · pregoButtonsSolid · scale
final _loveScale = _vector(
  keys: const [
    (at: 0.0, value: Offset(1, 1), curve: _easeIn),
    (at: 0.02468, value: Offset(0.95, 0.95), curve: _easeOut),
    (at: 0.09871, value: Offset(1.06, 1.06), curve: _spring4),
    (at: 0.33933, value: Offset(1, 1), curve: Curves.linear),
    (at: 1.0, value: Offset(1, 1), curve: Curves.linear),
  ],
);
