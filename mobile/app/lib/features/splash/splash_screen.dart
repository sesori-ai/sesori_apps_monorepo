import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SplashCubit(getIt()),
      child: const _SplashScreenBody(),
    );
  }
}

class _SplashScreenBody extends StatelessWidget {
  const _SplashScreenBody();

  @override
  Widget build(BuildContext context) {
    return BlocListener<SplashCubit, SplashState>(
      listener: (context, state) {
        if (state is SplashReady) {
          context.goRoute(state.route);
        }
      },
      child: const _SplashView(),
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

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
