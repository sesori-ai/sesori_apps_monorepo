import "package:freezed_annotation/freezed_annotation.dart";

import "../../routing/app_routes.dart";

part "splash_state.freezed.dart";

@Freezed()
sealed class SplashState with _$SplashState {
  const factory initializing() = SplashInitializing;

  const factory ready({required AppRoute route}) = SplashReady;
}
