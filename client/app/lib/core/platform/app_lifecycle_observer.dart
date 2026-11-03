import "dart:async";

import "package:flutter/widgets.dart";
import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

// NOTE: do NOT make it lazy singleton, otherwise it will not eagerly create the instance
// - eager creation is required to register the WidgetsBinding observer
@Singleton(as: LifecycleSource)
class AppLifecycleObserver() with WidgetsBindingObserver, Disposable implements LifecycleSource {
  final BehaviorSubject<LifecycleState> _lifecycleStateStream = BehaviorSubject.seeded(LifecycleState.resumed);

  @override
  ValueStream<LifecycleState> get lifecycleStateStream => _lifecycleStateStream.stream;

  this {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  FutureOr<void> onDispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleStateStream.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // resumed -> inactive -> hidden (synthetic state on mobile) -> paused -> detached
    _lifecycleStateStream.add(
      switch (state) {
        .resumed => .resumed,
        .inactive => .inactive,
        .hidden => .hidden,
        .paused => .paused,
        .detached => .detached,
      },
    );
  }
}
