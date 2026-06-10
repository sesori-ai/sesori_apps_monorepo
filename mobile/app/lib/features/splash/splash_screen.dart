import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/sesori_background_widget.dart";
import "../../core/widgets/sesori_logo.dart";

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

  /// Completes once [animation] settles. Used to hold navigation until the
  /// splash entrance transition finishes (after logout, splash is pushed
  /// with the platform transition and the cubit resolves within a few
  /// frames), so the login cross-fade and logo hero flight start from a
  /// screen at rest instead of mid-slide.
  Future<void> _settled(Animation<double> animation) {
    final completer = Completer<void>();
    void onStatus(AnimationStatus status) {
      if (status == .completed || status == .dismissed) {
        animation.removeStatusListener(onStatus);
        completer.complete();
      }
    }

    animation.addStatusListener(onStatus);
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SplashCubit, SplashState>(
      listener: (context, state) async {
        if (state is! SplashReady) return;
        final animation = ModalRoute.of(context)?.animation;
        if (animation != null && !animation.isCompleted) {
          await _settled(animation);
          if (!context.mounted) return;
        }
        context.goRoute(state.route);
      },
      child: const _SplashView(),
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned.fill(child: SesoriBackgroundWidget()),
        Align(
          alignment: .center,
          child: Hero(tag: SesoriLogo.heroTag, child: SesoriLogo()),
        ),
      ],
    );
  }
}
