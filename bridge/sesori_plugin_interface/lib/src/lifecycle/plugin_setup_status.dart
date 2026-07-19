import "package:meta/meta.dart";

/// Read-only result of inspecting whether a plugin can be activated.
///
/// Setup inspection runs before availability, provisioning, or plugin start. It
/// must never install a runtime, start a backend, or initiate authentication.
@immutable
sealed class PluginSetupStatus {
  const PluginSetupStatus();

  /// Generic, user-facing guidance authored by the plugin.
  String? get actionHint;
}

/// Setup was deliberately not inspected because the plugin is disabled.
final class PluginSetupNotInspected extends PluginSetupStatus {
  const PluginSetupNotInspected();

  @override
  String? get actionHint => null;

  @override
  bool operator ==(Object other) => other is PluginSetupNotInspected;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => "PluginSetupNotInspected";
}

/// The required runtime and authentication are already available.
final class PluginSetupReady extends PluginSetupStatus {
  const PluginSetupReady();

  @override
  String? get actionHint => null;

  @override
  bool operator ==(Object other) => other is PluginSetupReady;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => "PluginSetupReady";
}

/// No usable backend runtime was found.
final class PluginSetupRuntimeMissing extends PluginSetupStatus {
  const PluginSetupRuntimeMissing({required this.actionHint})
    : assert(actionHint != "", "PluginSetupRuntimeMissing.actionHint must not be empty");

  @override
  final String? actionHint;

  @override
  bool operator ==(Object other) => other is PluginSetupRuntimeMissing && other.actionHint == actionHint;

  @override
  int get hashCode => actionHint.hashCode;

  @override
  String toString() => "PluginSetupRuntimeMissing(actionHint: $actionHint)";
}

/// The runtime exists, but the backend requires authentication.
final class PluginSetupAuthenticationRequired extends PluginSetupStatus {
  const PluginSetupAuthenticationRequired({required this.actionHint})
    : assert(actionHint != "", "PluginSetupAuthenticationRequired.actionHint must not be empty");

  @override
  final String? actionHint;

  @override
  bool operator ==(Object other) => other is PluginSetupAuthenticationRequired && other.actionHint == actionHint;

  @override
  int get hashCode => actionHint.hashCode;

  @override
  String toString() => "PluginSetupAuthenticationRequired(actionHint: $actionHint)";
}

/// The backend is present but unsupported or otherwise unusable.
final class PluginSetupUnavailable extends PluginSetupStatus {
  const PluginSetupUnavailable({required this.actionHint})
    : assert(actionHint != "", "PluginSetupUnavailable.actionHint must not be empty");

  @override
  final String? actionHint;

  @override
  bool operator ==(Object other) => other is PluginSetupUnavailable && other.actionHint == actionHint;

  @override
  int get hashCode => actionHint.hashCode;

  @override
  String toString() => "PluginSetupUnavailable(actionHint: $actionHint)";
}

/// Setup could not be determined safely after a transient or ambiguous probe.
final class PluginSetupUnknown extends PluginSetupStatus {
  const PluginSetupUnknown({required this.actionHint})
    : assert(actionHint != "", "PluginSetupUnknown.actionHint must not be empty");

  @override
  final String? actionHint;

  @override
  bool operator ==(Object other) => other is PluginSetupUnknown && other.actionHint == actionHint;

  @override
  int get hashCode => actionHint.hashCode;

  @override
  String toString() => "PluginSetupUnknown(actionHint: $actionHint)";
}
