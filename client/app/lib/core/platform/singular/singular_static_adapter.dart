import "package:flutter/foundation.dart";
import "package:injectable/injectable.dart";
import "package:singular_flutter_sdk/singular.dart";
import "package:singular_flutter_sdk/singular_config.dart";

/// Injectable access to the static Singular SDK API.
@lazySingleton
class SingularStaticAdapter {
  new() : _start = Singular.start, _event = Singular.event;

  @visibleForTesting
  new test({
    required void Function(SingularConfig config) start,
    required void Function(String eventName) event,
  }) : _start = start,
       _event = event;

  final void Function(SingularConfig config) _start;
  final void Function(String eventName) _event;
  bool _isStarted = false;

  bool get isStarted => _isStarted;

  void start({required SingularConfig config}) {
    _start(config);
    _isStarted = true;
  }

  void event({required String eventName}) {
    if (!_isStarted) return;
    _event(eventName);
  }
}
