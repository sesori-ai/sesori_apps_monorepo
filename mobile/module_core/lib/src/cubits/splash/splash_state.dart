import "package:freezed_annotation/freezed_annotation.dart";

import "../../routing/app_routes.dart";

part "splash_state.freezed.dart";

@Freezed()
sealed class SplashState with _$SplashState {
  const factory SplashState.initializing() = SplashInitializing;

  const factory SplashState.ready({required AppRoute route}) = SplashReady;
}
