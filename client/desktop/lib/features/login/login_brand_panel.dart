import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:theme_prego/module_prego.dart";

/// How long the brand panel takes to fold away or come back.
const Duration _foldDuration = Duration(milliseconds: 200);

/// The product name is a brand, not copy, so it is not localized.
const String _productName = "Sesori";

/// The sign-in window's brand side: the aurora, the logo and a one-line pitch.
///
/// When [isVisible] turns false the panel fades while its width eases to
/// nothing, anchored at its trailing edge so the artwork slides out towards
/// the window's edge and the sign-in column beside it keeps its widgets.
class const LoginBrandPanel({
  super.key,
  required final bool isVisible,
  required final double width,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: isVisible ? 1 : 0),
      duration: prefersReducedMotion(context) ? Duration.zero : _foldDuration,
      curve: Curves.easeOut,
      child: const _BrandArtwork(),
      builder: (context, shown, artwork) {
        if (shown == 0) return const SizedBox.shrink();
        return ClipRect(
          child: SizedBox(
            width: width * shown,
            child: OverflowBox(
              alignment: AlignmentDirectional.centerEnd,
              minWidth: width,
              maxWidth: width,
              child: Opacity(opacity: shown, child: artwork),
            ),
          ),
        );
      },
    );
  }
}

class const _BrandArtwork() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    // The artwork is dark at the bottom in both themes, behind a scrim, so the
    // copy stays white whatever the theme.
    const onArtwork = Color(0xFFFFFFFF);

    return Stack(
      fit: StackFit.expand,
      children: [
        const SesoriBackgroundWidget(),
        const Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            heightFactor: 0.55,
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0x9E000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          start: 64,
          end: 64,
          bottom: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SesoriLogo(squareSize: 96),
              const SizedBox(height: 12),
              Text(_productName, style: prego.textTheme.displayMd.bold.copyWith(color: onArtwork)),
              const SizedBox(height: 6),
              Text(
                context.loc.desktopLoginTagline,
                style: prego.textTheme.textLg.regular.copyWith(color: onArtwork.withValues(alpha: 0.82)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
