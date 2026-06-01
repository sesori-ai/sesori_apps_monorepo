part of "../project_list_screen.dart";

// Asset paths for the "connect your computer" onboarding illustration.
const _kAuroraAsset = "assets/images/projects_onboarding/aurora_bg.png";
const _kSignalArcsAsset = "assets/images/projects_onboarding/signal_arcs.svg";
const _kFireflyDotsAsset = "assets/images/projects_onboarding/firefly_dots.svg";
const _kLaptopAsset = "assets/images/projects_onboarding/laptop.svg";

/// Stretches a [RadialGradient]'s circle into an ellipse that matches the
/// box's aspect ratio, so the fade reaches all four edges instead of only the
/// shorter pair. (`radius` is a fraction of the shortest side, so the circle
/// already spans the vertical edges; this scales it out along the wider axis.)
class _EllipseFit extends GradientTransform {
  const _EllipseFit();

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final shortest = bounds.shortestSide;
    if (shortest == 0) return null;
    final sx = bounds.width / shortest;
    final sy = bounds.height / shortest;
    final cx = bounds.center.dx;
    final cy = bounds.center.dy;
    // Scale about the box centre (column-major order): turns the gradient's
    // circle into an ellipse with the box's aspect ratio.
    return Matrix4(
      sx,
      0,
      0,
      0, //
      0,
      sy,
      0,
      0, //
      0,
      0,
      1,
      0, //
      cx * (1 - sx),
      cy * (1 - sy),
      0,
      1, //
    );
  }
}

/// The hero illustration: an aurora night scene behind a laptop with a
/// "cloud-slash" badge, framed by blurred signal arcs and firefly dots.
///
/// Layout positions mirror the Figma frame (294×284, illustration occupying
/// the top ~208px). The two SVGs carry Gaussian-blur filters that `flutter_svg`
/// cannot render, so the soft glow is reproduced with [ImageFiltered].
class _OnboardingHero extends StatelessWidget {
  const _OnboardingHero();

  @override
  Widget build(BuildContext context) {
    final auroraEdge = context.zyra.colors.bgPrimaryAlt;

    return SizedBox(
      width: double.infinity,
      height: 200,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Aurora landscape: a centred panel (sized by the factors below)
          // whose edges fade out via the foreground vignette. The fade colour
          // (auroraEdge) matches the Scaffold's bgPrimaryAlt background, so the
          // panel blends in seamlessly even though it doesn't span full width —
          // keep those two colours in sync. Image -> background decoration;
          // radial gradient -> foreground vignette painted on top.
          FractionallySizedBox(
            heightFactor: 0.6,
            widthFactor: 0.7,
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(_kAuroraAsset),
                  fit: BoxFit.cover,
                ),
              ),
              foregroundDecoration: BoxDecoration(
                gradient: RadialGradient(
                  // 0.5 makes the ellipse touch all four edges; _EllipseFit
                  // stretches the circle to the box's aspect ratio.
                  radius: 0.5,
                  transform: const _EllipseFit(),
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    auroraEdge.withValues(alpha: 0.5),
                    auroraEdge,
                  ],
                  stops: const [0.0, 0.42, 0.72, 1.0],
                ),
              ),
            ),
          ),
          // Glowing signal arcs above the laptop.
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
              child: SvgPicture.asset(_kSignalArcsAsset, width: 180, height: 180),
            ),
          ),
          // Laptop.
          Align(
            alignment: Alignment.bottomCenter,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SvgPicture.asset(_kLaptopAsset),
                Positioned(
                  top: 22,
                  child: ZyraButtonsIconGlass(
                    icon: TablerOutline.cloud_off,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
          // Scattered firefly dots.
          Positioned(
            child: SvgPicture.asset(_kFireflyDotsAsset),
          ),
        ],
      ),
    );
  }
}
