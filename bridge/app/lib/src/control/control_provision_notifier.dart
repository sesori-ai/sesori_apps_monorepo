import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/control_channel_client.dart";

/// Owns ALL outbound `provision_progress`-class control sends in supervised
/// mode: it maps a plugin's [RuntimeProvisionProgress] events onto the GUI
/// control channel as [ControlMessage.provisionProgress] frames so the GUI can
/// render first-run download/install progress. Higher layers (the runtime
/// runner's provisioning loop) hand each event to [notify] instead of touching
/// [ControlChannelClient.send] directly.
///
/// Fed synchronously one event at a time from the runner's existing
/// single-subscription provisioning loop, so it owns no subscription and no
/// lifecycle — there is nothing to dispose.
///
/// Sends are best-effort and never throw back into the provisioning loop: a
/// frame lost to a channel blip (or a slow/absent GUI) must never stall the
/// bridge's runtime provisioning, which is the load-bearing path. The wire
/// mirror [ControlProvisionProgress] deliberately omits the source type's
/// derived `fraction` getter (pure data); the GUI recomputes it.
class ControlProvisionNotifier {
  final ControlChannelClient _client;

  ControlProvisionNotifier({required ControlChannelClient client}) : _client = client;

  /// Tees a single provisioning event onto the control channel. Best-effort:
  /// swallows a not-connected channel (the GUI is briefly away) and any other
  /// send failure so provisioning is never blocked or crashed by a lost frame.
  void notify(RuntimeProvisionProgress event) {
    final message = ControlMessage.provisionProgress(progress: _mapProgress(event));
    try {
      _client.send(jsonEncode(message.toJson()));
    } on ControlChannelNotConnectedException {
      // Expected while the GUI is briefly away; first-run progress is
      // informational, so a dropped frame just means the GUI misses one tick.
      Log.d("[control][provision] channel down — dropping ${event.runtimeType}");
    } on Object catch (error, stackTrace) {
      Log.w("[control][provision] failed to send ${event.runtimeType}", error, stackTrace);
    }
  }

  ControlProvisionProgress _mapProgress(RuntimeProvisionProgress event) {
    return switch (event) {
      ProvisionResolving() => const ControlProvisionProgress.resolving(),
      ProvisionDownloading(:final receivedBytes, :final totalBytes) =>
        ControlProvisionProgress.downloading(receivedBytes: receivedBytes, totalBytes: totalBytes),
      ProvisionExtracting() => const ControlProvisionProgress.extracting(),
      ProvisionVerifying() => const ControlProvisionProgress.verifying(),
      ProvisionNotice(:final message) => ControlProvisionProgress.notice(message: message),
      ProvisionReady(:final binaryPath) => ControlProvisionProgress.ready(binaryPath: binaryPath),
      ProvisionFailed(:final message) => ControlProvisionProgress.failed(message: message),
    };
  }
}
