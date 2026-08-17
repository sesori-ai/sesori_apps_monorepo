import "package:meta/meta.dart";

/// Read-only result of inspecting whether a plugin can be activated.
///
/// Setup inspection runs before availability, provisioning, or plugin start. It
/// must never install a runtime, start a backend, or initiate authentication.
@immutable
sealed class const PluginSetupStatus() {
  /// Generic, user-facing guidance authored by the plugin.
  String? get actionHint;

  /// Display-ready version of the usable runtime selected by inspection.
  ///
  /// Null means inspection did not select a versioned local runtime. Raw
  /// command output must never be exposed through this field.
  String? get runtimeVersion;
}

/// Setup was deliberately not inspected because the plugin is disabled.
final class const PluginSetupNotInspected() extends PluginSetupStatus {
  @override
  String? get actionHint => null;

  @override
  String? get runtimeVersion => null;

  @override
  bool operator ==(Object other) => other is PluginSetupNotInspected;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => "PluginSetupNotInspected";
}

/// The required runtime and authentication are already available.
base class const PluginSetupReady() extends PluginSetupStatus {
  const factory versioned({required String runtimeVersion}) = _VersionedPluginSetupReady;

  @override
  String? get actionHint => null;

  @override
  String? get runtimeVersion => null;

  @override
  bool operator ==(Object other) => other is PluginSetupReady && other.runtimeVersion == runtimeVersion;

  @override
  int get hashCode => runtimeVersion.hashCode;

  @override
  String toString() => "PluginSetupReady(runtimeVersion: $runtimeVersion)";
}

final class const _VersionedPluginSetupReady({@override required final String runtimeVersion})
    extends PluginSetupReady {
  this : assert(runtimeVersion != "", "PluginSetupReady.runtimeVersion must not be empty"), super();
}

/// No usable backend runtime was found.
final class const PluginSetupRuntimeMissing({@override required final String? actionHint}) extends PluginSetupStatus {
  this : assert(actionHint != "", "PluginSetupRuntimeMissing.actionHint must not be empty");

  @override
  String? get runtimeVersion => null;

  @override
  bool operator ==(Object other) => other is PluginSetupRuntimeMissing && other.actionHint == actionHint;

  @override
  int get hashCode => actionHint.hashCode;

  @override
  String toString() => "PluginSetupRuntimeMissing(actionHint: $actionHint)";
}

/// The runtime exists, but the backend requires authentication.
base class const PluginSetupAuthenticationRequired({@override required final String? actionHint})
    extends PluginSetupStatus {
  this : assert(actionHint != "", "PluginSetupAuthenticationRequired.actionHint must not be empty");

  const factory versioned({
    required String? actionHint,
    required String runtimeVersion,
  }) = _VersionedPluginSetupAuthenticationRequired;

  @override
  String? get runtimeVersion => null;

  @override
  bool operator ==(Object other) =>
      other is PluginSetupAuthenticationRequired &&
      other.actionHint == actionHint &&
      other.runtimeVersion == runtimeVersion;

  @override
  int get hashCode => Object.hash(actionHint, runtimeVersion);

  @override
  String toString() => "PluginSetupAuthenticationRequired(actionHint: $actionHint, runtimeVersion: $runtimeVersion)";
}

final class const _VersionedPluginSetupAuthenticationRequired({
  required super.actionHint,
  @override required final String runtimeVersion,
}) extends PluginSetupAuthenticationRequired {
  this : assert(runtimeVersion != "", "PluginSetupAuthenticationRequired.runtimeVersion must not be empty"), super();
}

/// The backend is present but unsupported or otherwise unusable.
final class const PluginSetupUnavailable({@override required final String? actionHint}) extends PluginSetupStatus {
  this : assert(actionHint != "", "PluginSetupUnavailable.actionHint must not be empty");

  @override
  String? get runtimeVersion => null;

  @override
  bool operator ==(Object other) => other is PluginSetupUnavailable && other.actionHint == actionHint;

  @override
  int get hashCode => actionHint.hashCode;

  @override
  String toString() => "PluginSetupUnavailable(actionHint: $actionHint)";
}

/// Setup could not be determined safely after a transient or ambiguous probe.
base class const PluginSetupUnknown({@override required final String? actionHint}) extends PluginSetupStatus {
  this : assert(actionHint != "", "PluginSetupUnknown.actionHint must not be empty");

  const factory versioned({required String? actionHint, required String runtimeVersion}) = _VersionedPluginSetupUnknown;

  @override
  String? get runtimeVersion => null;

  @override
  bool operator ==(Object other) =>
      other is PluginSetupUnknown && other.actionHint == actionHint && other.runtimeVersion == runtimeVersion;

  @override
  int get hashCode => Object.hash(actionHint, runtimeVersion);

  @override
  String toString() => "PluginSetupUnknown(actionHint: $actionHint, runtimeVersion: $runtimeVersion)";
}

final class const _VersionedPluginSetupUnknown({
  required super.actionHint,
  @override required final String runtimeVersion,
}) extends PluginSetupUnknown {
  this : assert(runtimeVersion != "", "PluginSetupUnknown.runtimeVersion must not be empty"), super();
}
