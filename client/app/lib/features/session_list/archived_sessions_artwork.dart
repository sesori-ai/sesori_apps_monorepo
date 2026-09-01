import "package:material_ui/material_ui.dart";

/// Mobile-owned artwork for the shared archived-sessions empty state.
///
/// The image exports remain product assets; shared presentation receives this
/// widget through shell composition instead of naming a product asset path.
class const ArchivedSessionsArtwork({super.key}) extends StatelessWidget {
  static const double _width = 210;
  static const double _height = 75;
  static const double _fadeTopOpacity = 0.61;
  static const double _fadeBottomOpacity = 0.11;

  static const String _directory = "assets/images/archived_sessions_empty";
  static const String _lightAsset = "$_directory/archive_stack-light.png";
  static const String _darkAsset = "$_directory/archive_stack-dark.png";

  @override
  Widget build(BuildContext context) {
    final asset = Theme.brightnessOf(context) == Brightness.dark ? _darkAsset : _lightAsset;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: _fadeTopOpacity),
          Colors.white.withValues(alpha: _fadeBottomOpacity),
        ],
      ).createShader(bounds),
      child: Image.asset(
        asset,
        width: _width,
        height: _height,
        fit: BoxFit.contain,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
