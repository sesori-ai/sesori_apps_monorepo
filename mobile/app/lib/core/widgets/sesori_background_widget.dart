import 'package:flutter/material.dart';

import '../extensions/build_context_x.dart';

class SesoriBackgroundWidget extends StatelessWidget {
  const SesoriBackgroundWidget({super.key});

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
      fit: .cover,
    );
  }
}
