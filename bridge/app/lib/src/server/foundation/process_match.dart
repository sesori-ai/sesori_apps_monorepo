import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

enum ProcessMatchKind() { sesoriBridge, unknown }

class const ProcessMatch({
    required final ProcessIdentity identity,
    required final ProcessMatchKind kind,
    required final bool isCurrentUserProcess,
  });
