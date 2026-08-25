import "package:flutter/foundation.dart";
import "package:singular_flutter_sdk/singular.dart";
import "package:singular_flutter_sdk/singular_config.dart";

/// Injectable access to the static Singular SDK API.
class SingularStaticAdapter {
  new enabled() : _start = Singular.start;

  @visibleForTesting
  const new test({required void Function(SingularConfig config) start}) : _start = start;

  final void Function(SingularConfig config) _start;

  void start({required SingularConfig config}) => _start(config);
}
