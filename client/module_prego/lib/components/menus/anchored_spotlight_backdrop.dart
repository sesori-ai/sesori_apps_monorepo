import "package:cue/cue.dart";
import "package:flutter/material.dart";

import "../../theme/prego_glass.dart";
import "../../theme/prego_theme.dart";

/// The backdrop of an anchored popup: the page behind it recedes, except for a
/// sharp rounded cut-out around the widget the popup is anchored to.
///
/// This is the flat counterpart of an iOS context menu's backdrop. Everything
/// falls back — a Gaussian blur plus a scrim — while the anchored widget stays at
/// full contrast and gains a hairline outline, so the row a long-press menu is
/// about to act on is unmistakable while the rest of the list is pushed away.
///
/// The blur is Apple-only ([glassEffectsEnabled]): a full-screen [BackdropFilter]
/// is the cost this module's flat path exists to keep off Android. There the
/// scrim, the cut-out and the outline carry the effect alone.
///
/// Blur and scrim ramp in with the popup and back out with it: both ride [Actor]s,
/// which the enclosing `CueDialogRoute`'s scope drives forward on push and in
/// reverse on pop — the same timeline `AnchoredFlatPanel` springs its panel on.
///
/// Pointer-transparent by design: the popup's dismiss barrier sits below it in
/// the route and must keep receiving tap-outside.
class AnchoredSpotlightBackdrop extends StatelessWidget {
  const AnchoredSpotlightBackdrop({
    super.key,
    required this.spotlightRect,
    required this.borderRadius,
  });

  /// Screen-space rectangle left sharp — the anchored widget's bounds, already
  /// inset by the caller.
  final Rect spotlightRect;

  /// Corner radius of the sharp cut-out.
  final double borderRadius;

  /// Gaussian sigma the page blurs to. Enough to take the surrounding rows out
  /// of legibility without smearing the page into an unreadable wash — the
  /// user should still recognise the list they came from.
  static const double _blurSigma = 5;

  /// Opacity of the scrim laid over the blur.
  ///
  /// The scrim is the page's own surface colour rather than a fixed black, so it
  /// washes the backdrop toward the page in both themes. A fixed black would be
  /// wrong in light mode, and the design system's `alphaBlack*` tokens are
  /// contrast overlays (white on a dark theme), so they would *brighten* a dark
  /// page rather than push it back.
  static const double _scrimOpacity = 0.4;

  /// Scrim opacity where the blur is skipped — deeper, because the scrim is then
  /// carrying the separation on its own.
  static const double _unblurredScrimOpacity = 0.6;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final radius = Radius.circular(borderRadius);

    // The Gaussian pass is the expensive half of this backdrop, and a full-screen
    // BackdropFilter is the very cost the flat path exists to keep off Android
    // (see [glassEffectsEnabled]). Android keeps the scrim, the cut-out and the
    // outline — the page still recedes and the anchored widget still reads as
    // lifted — and skips only the blur, taking a deeper scrim in its place.
    final blurred = glassEffectsEnabled();

    // The backdrop rides the popup's follower so the cut-out stays glued to its
    // anchor when the page relayouts under the open menu (a banner dropping in
    // above the list, a row growing a line). The scrim is translated by that same
    // relayout, so it is drawn far larger than the viewport: a screen-sized scrim
    // would slide off one edge and leave a sharp, un-dimmed band along the other.
    final screen = MediaQuery.sizeOf(context);
    final canvas = (Offset.zero & screen).inflate(screen.longestSide);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: canvas,
            child: ClipPath(
              // Shifted into the oversized canvas's own coordinate space.
              clipper: _SpotlightHoleClipper(
                hole: RRect.fromRectAndRadius(spotlightRect, radius).shift(-canvas.topLeft),
              ),
              // Acts nest in reverse, which puts the BackdropFilter OUTSIDE the
              // scrim's Opacity. That order matters: an Opacity above the filter
              // would save a layer, and the filter would then sample that layer
              // instead of the page painted beneath the route.
              child: Actor(
                acts: blurred
                    ? const [Act.backdropBlur(to: _blurSigma), Act.fadeIn()]
                    : const [Act.fadeIn()],
                child: ColoredBox(
                  color: prego.colors.bgSurface1.withValues(
                    alpha: blurred ? _scrimOpacity : _unblurredScrimOpacity,
                  ),
                ),
              ),
            ),
          ),
          // Outlines the cut-out. The anchored widget itself is painted by the
          // page below and cannot be given elevation from here, so the hairline
          // is what reads as "lifted" against the blur.
          Positioned.fromRect(
            rect: spotlightRect,
            child: Actor(
              acts: const [Act.fadeIn()],
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(radius),
                  border: Border.all(color: prego.colors.borderSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Clips to the whole layer *minus* [hole] — so the blur and scrim it wraps
/// never paint over the anchored widget.
class _SpotlightHoleClipper extends CustomClipper<Path> {
  const _SpotlightHoleClipper({required this.hole});

  final RRect hole;

  @override
  Path getClip(Size size) {
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(hole),
    );
  }

  @override
  bool shouldReclip(_SpotlightHoleClipper oldClipper) => oldClipper.hole != hole;
}
