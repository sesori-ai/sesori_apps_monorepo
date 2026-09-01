import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// Width/height ratio of a preview tile, from the Figma 96×69 tile.
const double _previewAspectRatio = 96 / 69;

/// Corner radius of a preview tile, and of the selection ring around it.
const double _previewRadius = PregoRadius.xl;
const double _selectionRingWidth = 2.0;
const double _selectionRadius = _previewRadius + _selectionRingWidth;

/// Horizontal gap between the three tiles.
const double _optionGap = PregoSpacing.x3l;

/// Gap between a tile and its label.
const double _labelGap = PregoSpacing.sm;

/// The Figma "Appearance" section: three theme previews (light, dark, and a
/// diagonally split "system") that switch the app's theme when tapped.
///
/// Reads and writes the app-wide [AppearanceCubit] the shell resolves its
/// [ThemeMode] from, so a tap re-themes the whole app immediately.
class const AppearancePicker({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final cubit = context.watch<AppearanceCubit>();
    final labels = <AppearanceMode, String>{
      AppearanceMode.light: loc.settingsAppearanceLight,
      AppearanceMode.dark: loc.settingsAppearanceDark,
      AppearanceMode.system: loc.settingsAppearanceSystem,
    };

    return Padding(
      // The tiles sit inset from the section header, matching the card
      // padding the neighbouring grouped-row sections have.
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xl),
      child: Row(
        spacing: _optionGap,
        children: [
          for (final MapEntry(key: mode, value: label) in labels.entries)
            Expanded(
              child: _AppearanceOption(
                mode: mode,
                label: label,
                isSelected: cubit.state == mode,
                onTap: () => cubit.select(mode: mode),
              ),
            ),
        ],
      ),
    );
  }
}

/// One theme choice: a preview tile in a selection ring, with its label below.
class const _AppearanceOption({
  required final AppearanceMode mode,
  required final String label,
  required final bool isSelected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return MergeSemantics(
      child: Semantics(
        // The three tiles are one choice, not three independent buttons — the
        // same semantics a [Radio] carries, so assistive technology announces
        // the selection as mutually exclusive.
        inMutuallyExclusiveGroup: true,
        checked: isSelected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                // A Container (rather than a DecoratedBox) so the ring insets
                // the preview instead of being painted underneath it. The ring
                // stays transparent when unselected, so selecting one tile
                // never resizes the row.
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_selectionRadius),
                  border: Border.all(
                    color: isSelected ? prego.colors.borderBrand : Colors.transparent,
                    width: _selectionRingWidth,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_previewRadius),
                  child: AspectRatio(
                    aspectRatio: _previewAspectRatio,
                    child: switch (mode) {
                      AppearanceMode.light => const _ThemePreview(palette: PregoColors.light),
                      AppearanceMode.dark => const _ThemePreview(palette: PregoColors.dark),
                      AppearanceMode.system => const _SystemThemePreview(),
                    },
                  ),
                ),
              ),
              const SizedBox(height: _labelGap),
              Text(
                label,
                style: prego.textTheme.textSm.regular.copyWith(
                  color: isSelected ? prego.colors.textPrimary : prego.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A stylised mini session screen: an assistant bubble carrying a brand-colour
/// line, and the composer pill with its microphone button.
///
/// Drawn from [palette] rather than the ambient theme — a preview has to show
/// its own theme regardless of which one the app is currently rendering in.
class const _ThemePreview({required final PregoColors palette}) extends StatelessWidget {
  /// Fractions of the tile, measured off the Figma tile. Everything is
  /// relative so the mock scales with the available width.
  static const double _bubbleBleed = 0.08;
  static const double _bubbleTop = 0.09;
  static const double _bubbleWidth = 0.65;
  static const double _bubbleHeight = 0.29;
  static const double _bubbleLineWidthFactor = 0.62;
  static const double _bubbleLineHeightFactor = 0.25;
  static const double _composerBleed = 0.15;
  static const double _composerTop = 0.44;
  static const double _composerWidth = 1.01;
  static const double _composerHeight = 0.46;
  static const double _micSize = 0.15;
  static const Alignment _micAlignment = Alignment(0.66, 0);

  @override
  Widget build(BuildContext context) {
    // The canvas is the app background of the previewed theme: white in light,
    // near-black in dark. Bubbles and the composer sit on it as surfaces.
    final canvas = palette.brightness == Brightness.light ? palette.bgSurface3 : palette.bgSurface1;
    final surface = BoxDecoration(
      color: palette.bgSurface3,
      border: Border.all(color: palette.borderSecondary),
      borderRadius: BorderRadius.circular(PregoRadius.full),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return DecoratedBox(
          decoration: BoxDecoration(color: canvas),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: -width * _bubbleBleed,
                top: height * _bubbleTop,
                width: width * _bubbleWidth,
                height: height * _bubbleHeight,
                child: DecoratedBox(
                  decoration: surface,
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: _bubbleLineWidthFactor,
                      heightFactor: _bubbleLineHeightFactor,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.bgBrandSolid,
                          borderRadius: BorderRadius.circular(PregoRadius.full),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -width * _composerBleed,
                top: height * _composerTop,
                width: width * _composerWidth,
                height: height * _composerHeight,
                child: DecoratedBox(
                  decoration: surface,
                  child: Align(
                    alignment: _micAlignment,
                    child: Icon(
                      TablerRegular.microphone,
                      size: width * _micSize,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The "system" tile: the dark preview masked to the top-left triangle over
/// the light one, so the tile shows both themes split along the diagonal.
class const _SystemThemePreview() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        _ThemePreview(palette: PregoColors.light),
        ClipPath(
          clipper: _TopLeftTriangleClipper(),
          child: _ThemePreview(palette: PregoColors.dark),
        ),
      ],
    );
  }
}

/// Clips to the triangle above the top-right/bottom-left diagonal.
class const _TopLeftTriangleClipper() extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(size.width, 0)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
