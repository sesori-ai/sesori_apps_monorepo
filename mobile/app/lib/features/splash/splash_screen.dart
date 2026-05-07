import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/sesori_background_widget.dart";

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
        // return;
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
    final zyra = context.zyra;
    return Stack(
      clipBehavior: .none,
      children: [
        const Positioned.fill(child: SesoriBackgroundWidget()),
        Align(
          alignment: .center,
          child: Column(
            mainAxisSize: .min,
            children: [
              Image.asset(
                "assets/images/sesori_icon_with_shadow.png",
                fit: .none,
              ),
              // Image has some embedded "bottom padding"
              // caused by the shadow
              const SizedBox(height: 13),
              Text(
                context.loc.splashWelcomeTo,
                style: zyra.textTheme.textSm.regular,
              ),
              Text(
                context.loc.splashTitle,
                style: zyra.textTheme.textMd.bold,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
