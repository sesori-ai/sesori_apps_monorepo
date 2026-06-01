part of "../project_list_screen.dart";

// Asset paths for the "connect your computer" onboarding illustration.
const _kAuroraAsset = "assets/images/projects_onboarding/aurora_bg.png";
const _kSignalArcsAsset = "assets/images/projects_onboarding/signal_arcs.svg";
const _kFireflyDotsAsset = "assets/images/projects_onboarding/firefly_dots.svg";
const _kLaptopAsset = "assets/images/projects_onboarding/laptop.svg";

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
          // Aurora landscape, faded into the background at the edges.
          Align(
            alignment: Alignment.bottomCenter,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(_kAuroraAsset, fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 0.9,
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
              ],
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
