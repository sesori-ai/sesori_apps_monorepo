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

  void start({required SingularConfig config}) => _start(config);

  void event({required String eventName}) => _event(eventName);
}
