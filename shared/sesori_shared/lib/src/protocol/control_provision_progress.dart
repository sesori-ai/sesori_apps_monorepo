import "package:freezed_annotation/freezed_annotation.dart";

part "control_provision_progress.freezed.dart";
part "control_provision_progress.g.dart";

/// Wire mirror of the bridge's `RuntimeProvisionProgress` (which lives in
/// `sesori_plugin_interface` and cannot be imported here — `sesori_shared` is
/// the shared leaf both workspaces depend on). In supervised mode the bridge
/// tees its provisioning stream onto the control channel as these DTOs so the
/// GUI can render first-run download/install progress (PR 1.13).
///
/// Pure data only: the source type's derived `fraction` getter is intentionally
/// omitted — consumers compute it from [ControlProvisionDownloading.totalBytes].
@Freezed(unionKey: "type", unionValueCase: FreezedUnionCase.snake, fromJson: true, toJson: true)
sealed class ControlProvisionProgress with _$ControlProvisionProgress {
  /// Deciding which runtime to use; no bytes fetched yet.
  @FreezedUnionValue("resolving")
  const factory ControlProvisionProgress.resolving() = ControlProvisionResolving;

  /// Downloading the managed runtime archive. [totalBytes] is null when the
  /// server did not advertise a length (progress is then indeterminate).
  @FreezedUnionValue("downloading")
  const factory ControlProvisionProgress.downloading({
    required int receivedBytes,
    required int? totalBytes,
  }) = ControlProvisionDownloading;

  /// Unpacking the downloaded archive into its versioned install directory.
  @FreezedUnionValue("extracting")
  const factory ControlProvisionProgress.extracting() = ControlProvisionExtracting;

  /// Verifying the downloaded archive against its pinned checksum.
  @FreezedUnionValue("verifying")
  const factory ControlProvisionProgress.verifying() = ControlProvisionVerifying;

  /// A non-terminal, user-facing notice surfaced mid-provision.
  @FreezedUnionValue("notice")
  const factory ControlProvisionProgress.notice({required String message}) = ControlProvisionNotice;

  /// Terminal success: the runtime is ready; [binaryPath] is the launch target.
  @FreezedUnionValue("ready")
  const factory ControlProvisionProgress.ready({required String binaryPath}) = ControlProvisionReady;

  /// Terminal failure (non-fatal): the runtime could not be provisioned;
  /// [message] explains what went wrong for logs/diagnostics.
  @FreezedUnionValue("failed")
  const factory ControlProvisionProgress.failed({required String message}) = ControlProvisionFailed;

  factory ControlProvisionProgress.fromJson(Map<String, dynamic> json) =>
      _$ControlProvisionProgressFromJson(json);
}
