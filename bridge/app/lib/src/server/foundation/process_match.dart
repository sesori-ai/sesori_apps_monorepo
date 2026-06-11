import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

enum ProcessMatchKind { sesoriBridge, unknown }

class ProcessMatch {
  const ProcessMatch({
    required this.identity,
    required this.kind,
    required this.isCurrentUserProcess,
  });

  final ProcessIdentity identity;
  final ProcessMatchKind kind;
  final bool isCurrentUserProcess;
}
