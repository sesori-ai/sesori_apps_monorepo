import 'package:rxdart/rxdart.dart';

abstract interface class LifecycleSource {
  ValueStream<LifecycleState> get lifecycleStateStream;
}

extension LifecycleSourceX on LifecycleSource {
  LifecycleState get lifecycleState => lifecycleStateStream.value;
}

enum LifecycleState {
  // Engine with no view. All platforms start in this state.
  // * Android & iOS & Web -> can re-enter this state (engine with no view)
  // * Desktop -> NEVER RE-ENTERS THIS STATE
  detached,

  // App is visible and in focus
  resumed,

  // when app has no focus
  // * -> Android -- split screen interacting with other app
  // * -> iOS -- receiving phone call while using app
  // * -> Web -- running in a window or tab that does not have input focus
  // * -> Desktop -- app not in focus (user is interacting with other app)
  inactive,

  // when app is no longer visible to the user
  // * Mobile -> app is about to be paused
  // * Web -> running in a window or tab that is no longer visible
  // * Desktop -> app was minimized or placed on a desktop that is no longer visible
  hidden,

  // when app is no longer visible to the user
  // * Mobile -> app is paused (backgrounded)
  // * Web & Desktop -> NEVER ENTER THIS STATE
  paused,
}
