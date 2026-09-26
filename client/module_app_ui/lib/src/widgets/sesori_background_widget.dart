import "package:material_ui/material_ui.dart";

import "../extensions/build_context_x.dart";

/// The Sesori aurora artwork, filling its box, in the current theme and
/// orientation.
class const SesoriBackgroundWidget({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.orientationOf(context);
    final brightness = context.brightness;
    final imageFile = switch ((orientation, brightness)) {
      (.portrait, .light) => "assets/images/bkg_webp/light_mode_portrait_splash.webp",
      (.landscape, .light) => "assets/images/bkg_webp/light_mode_landscape_splash.webp",
      (.portrait, .dark) => "assets/images/bkg_webp/dark_mode_portrait_splash.webp",
      (.landscape, .dark) => "assets/images/bkg_webp/dark_mode_landscape_splash.webp",
    };

    return Image.asset(
      imageFile,
      package: "sesori_app_ui",
      fit: .cover,
    );
  }
}
