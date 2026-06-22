part of "../project_list_screen.dart";

// Asset paths for the "connect your computer" onboarding illustration.
// The aurora backdrop and laptop each ship light/dark variants, picked by the
// active Prego brightness in build(); the remaining assets are theme-agnostic.
const _kAuroraDarkAsset = "assets/images/projects_onboarding/aurora_bg-dark.jpeg";
const _kAuroraLightAsset = "assets/images/projects_onboarding/aurora_bg-light.jpeg";
const _kSignalArcsAsset = "assets/images/projects_onboarding/signal_arcs.svg";
const _kFireflyDotsAsset = "assets/images/projects_onboarding/firefly_dots.svg";
const _kLaptopDarkAsset = "assets/images/projects_onboarding/laptop-dark.svg";
const _kLaptopLightAsset = "assets/images/projects_onboarding/laptop-light.svg";
const _kCliAsset = "assets/images/projects_onboarding/cli.svg";

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

/// Which onboarding state the hero illustration depicts.
enum _OnboardingHeroVariant {
  /// Bridge not connected yet: a cloud-slash badge and no signal arcs —
  /// nothing is reaching the computer.
  offline,

  /// Bridge connected but no projects yet: a terminal-window badge framed by
  /// glowing signal arcs that read as a live connection.
  cli,
}

/// The hero illustration: an aurora landscape behind a laptop, with a badge
/// on the laptop and scattered firefly dots. The aurora backdrop and laptop
/// swap between light/dark artwork to match the active Prego brightness.
///
/// Comes in two [variant]s, one per empty onboarding state:
/// * [_OnboardingHeroVariant.offline] — bridge not connected yet: a
///   "cloud-slash" badge, no signal arcs.
/// * [_OnboardingHeroVariant.cli] — bridge connected but no projects yet: a
///   terminal-window badge framed by glowing signal arcs above the laptop.
///
/// Laid out as a fixed 200px-tall [Stack] aligned to the bottom (adapted from
/// the Figma frame). The signal arcs' SVG carries a Gaussian-blur filter that
/// `flutter_svg` cannot render, so its soft glow is reproduced with
/// [ImageFiltered].
class _OnboardingHero extends StatelessWidget {
  const _OnboardingHero.offline() : variant = _OnboardingHeroVariant.offline;

  const _OnboardingHero.cli() : variant = _OnboardingHeroVariant.cli;

  final _OnboardingHeroVariant variant;

  @override
  Widget build(BuildContext context) {
    // Read brightness off the same PregoColors instance that supplies the
    // vignette edge below, so the artwork and the fade colour can't disagree.
    final colors = context.prego.colors;
    final auroraEdge = colors.bgSecondary;
    final isDark = colors.brightness == Brightness.dark;
    final auroraAsset = isDark ? _kAuroraDarkAsset : _kAuroraLightAsset;
    final laptopAsset = isDark ? _kLaptopDarkAsset : _kLaptopLightAsset;
    final showSignalArcs = variant == _OnboardingHeroVariant.cli;

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
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(auroraAsset),
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
          // Glowing signal arcs above the laptop — CLI variant only, where
          // they read as a live signal.
          if (showSignalArcs)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
                child: SvgPicture.asset(_kSignalArcsAsset, width: 180, height: 180),
              ),
            ),
          // Laptop with its variant-specific badge.
          Align(
            alignment: Alignment.bottomCenter,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SvgPicture.asset(laptopAsset),
                Positioned(top: 22, child: _badge()),
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

  /// The element sitting on the laptop: a cloud-slash glass badge when offline,
  /// or the terminal-window illustration in the CLI variant.
  Widget _badge() {
    return switch (variant) {
      _OnboardingHeroVariant.offline => PregoButtonsIconGlass(
        icon: TablerRegular.cloud_off,
        onPressed: () {},
      ),
      _OnboardingHeroVariant.cli => SvgPicture.asset(_kCliAsset),
    };
  }
}
