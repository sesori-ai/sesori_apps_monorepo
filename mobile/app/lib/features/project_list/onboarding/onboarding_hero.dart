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
      width: 294,
      height: 208,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Aurora landscape, faded into the background at the edges.
          Positioned(
            left: 1,
            top: 90,
            child: SizedBox(
              width: 292,
              height: 117,
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
          ),
          // Glowing signal arcs above the laptop.
          Positioned(
            left: 57,
            top: 0,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 2.2, sigmaY: 2.2),
              child: SvgPicture.asset(_kSignalArcsAsset, width: 180, height: 180),
            ),
          ),
          // Scattered firefly dots.
          Positioned(
            left: 78,
            top: 81,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
              child: SvgPicture.asset(_kFireflyDotsAsset, width: 170, height: 97),
            ),
          ),
          // Laptop.
          Positioned(
            left: 76,
            top: 97,
            child: SvgPicture.asset(_kLaptopAsset),
          ),
          // Cloud-slash badge centred on the laptop screen.
          Positioned(
            left: 123,
            top: 120,
            child: ZyraButtonsIconGlass(
              icon: TablerOutline.cloud_off,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}
