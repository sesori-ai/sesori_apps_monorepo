import "dart:io";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

class const _Manifest() extends RuntimeManifest {
  @override
  String get runtimeId => "runtime";

  @override
  String get displayName => "Runtime";

  @override
  String get installDocsUrl => "https://example.test";

  @override
  String get pathExecutableName => "runtime";

  @override
  String get binaryFileName => "runtime";

  @override
  RuntimeVersion get minPathVersion => SemanticRuntimeVersion.parse(value: "1.0.0");

  @override
  RuntimeVersion get bundledVersion => SemanticRuntimeVersion.parse(value: "2.0.0");

  @override
  RuntimeVersion? parseVersion({required String value}) => SemanticRuntimeVersion.tryParse(value: value);

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) => null;

  @override
  String downloadUrlFor({required RuntimeAsset asset}) => "https://example.test/${asset.assetName}";
}

void main() {
  final missing = ManagedRuntimeProbeRejected(
    outcome: RuntimeProbeMissing(innerError: const ProcessException("runtime", []), stackTrace: StackTrace.empty),
  );
  const broken = ManagedRuntimeProbeRejected(outcome: RuntimeProbeUnrecognized());
  final old = ManagedRuntimeVersionRejected(version: SemanticRuntimeVersion.parse(value: "0.9.0"));

  PluginSetupStatus map({required ManagedRuntimeNotSelected notSelected, required bool supportsManagedInstall}) =>
      const ManagedRuntimeSetupStatusMapper().map(
        manifest: const _Manifest(),
        notSelected: notSelected,
        supportsManagedInstall: supportsManagedInstall,
      );

  test("maps a PATH runtime rejection", () {
    expect(
      map(notSelected: ManagedRuntimePathNotSelected(primaryRejection: old), supportsManagedInstall: true),
      isA<PluginSetupRuntimeOutdated>()
          .having((status) => status.actionHint, "hint", "Update the global Runtime installation to 1.0.0 or newer.")
          .having((status) => status.runtimeVersion, "version", "0.9.0"),
    );
    expect(
      map(notSelected: const ManagedRuntimePathNotSelected(primaryRejection: broken), supportsManagedInstall: true),
      isA<PluginSetupUnknown>(),
    );
  });

  test("maps an explicit runtime rejection", () {
    expect(
      map(notSelected: ManagedRuntimeExplicitNotSelected(primaryRejection: missing), supportsManagedInstall: true),
      isA<PluginSetupRuntimeMissing>().having(
        (status) => status.actionHint,
        "hint",
        "Fix the configured Runtime CLI path, then restart the bridge.",
      ),
    );
    expect(
      map(notSelected: ManagedRuntimeExplicitNotSelected(primaryRejection: old), supportsManagedInstall: true),
      isA<PluginSetupUnavailable>(),
    );
    expect(
      map(notSelected: const ManagedRuntimeExplicitNotSelected(primaryRejection: broken), supportsManagedInstall: true),
      isA<PluginSetupUnknown>(),
    );
  });

  test("maps an automatic selection that found nothing usable", () {
    expect(
      map(
        notSelected: ManagedRuntimeAutomaticNotSelected(primaryRejection: missing, managedRejection: broken),
        supportsManagedInstall: true,
      ),
      isA<PluginSetupUnknown>(),
    );
    expect(
      map(
        notSelected: ManagedRuntimeAutomaticNotSelected(primaryRejection: missing, managedRejection: missing),
        supportsManagedInstall: true,
      ),
      isA<PluginSetupRuntimeMissing>().having(
        (status) => status.actionHint,
        "hint",
        "Install Runtime from Sesori, or install it locally and retry setup detection.",
      ),
    );
    expect(
      map(
        notSelected: ManagedRuntimeAutomaticNotSelected(primaryRejection: missing, managedRejection: old),
        supportsManagedInstall: false,
      ),
      isA<PluginSetupRuntimeMissing>().having(
        (status) => status.actionHint,
        "hint",
        "Install Runtime locally, then retry setup detection.",
      ),
    );
  });
}
