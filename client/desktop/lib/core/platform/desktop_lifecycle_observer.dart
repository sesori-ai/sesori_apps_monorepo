import "dart:async";

import "package:flutter/widgets.dart";
import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

// NOTE: do NOT make it lazy singleton — eager creation is required to register
// the WidgetsBinding observer before the first lifecycle event.
@Singleton(as: LifecycleSource)
class DesktopLifecycleObserver with WidgetsBindingObserver, Disposable implements LifecycleSource {
  final BehaviorSubject<LifecycleState> _lifecycleStateStream = BehaviorSubject.seeded(LifecycleState.resumed);

  @override
  ValueStream<LifecycleState> get lifecycleStateStream => _lifecycleStateStream.stream;

  DesktopLifecycleObserver() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  FutureOr<void> onDispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleStateStream.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Desktop lifecycle: resumed -> inactive -> hidden; paused/detached are
    // never re-entered on desktop but mapped for exhaustiveness.
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
