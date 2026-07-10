import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../bridge/repositories/mappers/runtime_provision_progress_mapper.dart";
import "../foundation/control_channel_client.dart";

/// Owns ALL outbound provision-class control sends in supervised mode: it maps
/// the bridge's runtime-provisioning progress to the shared wire DTOs and
/// pushes them to the GUI over the injected [ControlChannelClient] so it can
/// render first-run download/install progress. Higher layers (the runner's
/// provisioning loop) never call `ControlChannelClient.send` directly.
///
/// This is the provisioning-progress analogue of `ControlStatusNotifier`
/// (status-class sends). Unlike the status notifier it observes no stream and
/// owns no subscription: provisioning is consumed synchronously by the runner
/// (which records `ProvisionReady.binaryPath`), so events arrive as a typed
/// fed sink via [handleProvisionProgress]. It therefore has nothing to dispose.
/// Download events are coalesced here, at the outbound transport seam, so local
/// consumers retain per-chunk progress without flooding the GUI control channel.
///
/// Sends are best-effort and never throw to the caller: progress is
/// informational, and a frame lost to a channel blip only skips a UI update —
/// the terminal `ready`/`failed` state still governs the plugin's health.
class ControlProvisionNotifier {
  static const int _unknownTotalStepBytes = 512 * 1024;

  final ControlChannelClient _client;

  int? _downloadTotalBytes;
  int? _lastObservedDownloadBytes;
  int? _lastSentDownloadBytes;
  int? _lastSentDownloadPercent;

  ControlProvisionNotifier({required ControlChannelClient client}) : _client = client;

  /// Typed feed from the runner's provisioning loop: maps [event] to its wire
  /// DTO and best-effort sends it to the GUI.
  void handleProvisionProgress({required RuntimeProvisionProgress event}) {
    if (!_shouldSend(event: event)) {
      return;
    }
    final message = ControlMessage.provisionProgress(
      progress: event.toControlProvisionProgress(),
    );
    try {
      _client.send(jsonEncode(message.toJson()));
    } on ControlChannelNotConnectedException {
      // Expected while the GUI is briefly away; a dropped progress frame only
      // skips a UI update, so there is no re-sync to attempt.
      Log.d("[control][provision] channel down — dropping progress frame");
    } on Object catch (error, stackTrace) {
      Log.w("[control][provision] failed to send progress frame", error, stackTrace);
    }
  }

  bool _shouldSend({required RuntimeProvisionProgress event}) {
    switch (event) {
      case ProvisionDownloading(:final receivedBytes, :final totalBytes):
        return _shouldSendDownload(receivedBytes: receivedBytes, totalBytes: totalBytes);
      case ProvisionResolving():
      case ProvisionExtracting():
      case ProvisionVerifying():
      case ProvisionNotice():
      case ProvisionReady():
      case ProvisionFailed():
        _resetDownloadProgress();
        return true;
    }
  }

  bool _shouldSendDownload({required int receivedBytes, required int? totalBytes}) {
    final effectiveTotalBytes = totalBytes != null && totalBytes > 0 ? totalBytes : null;
    final isNewDownload =
        _lastObservedDownloadBytes == null ||
        _downloadTotalBytes != effectiveTotalBytes ||
        receivedBytes < _lastObservedDownloadBytes!;
    if (isNewDownload) {
      _resetDownloadProgress();
      _downloadTotalBytes = effectiveTotalBytes;
    }
    _lastObservedDownloadBytes = receivedBytes;

    if (effectiveTotalBytes != null) {
      final boundedReceivedBytes = receivedBytes.clamp(0, effectiveTotalBytes);
      final percent = boundedReceivedBytes * 100 ~/ effectiveTotalBytes;
      final lastPercent = _lastSentDownloadPercent;
      if (lastPercent != null && percent <= lastPercent) {
        return false;
      }
      _lastSentDownloadPercent = percent;
      _lastSentDownloadBytes = receivedBytes;
      return true;
    }

    final lastSentBytes = _lastSentDownloadBytes;
    if (lastSentBytes != null && receivedBytes - lastSentBytes < _unknownTotalStepBytes) {
      return false;
    }
    _lastSentDownloadBytes = receivedBytes;
    return true;
  }

  void _resetDownloadProgress() {
    _downloadTotalBytes = null;
    _lastObservedDownloadBytes = null;
    _lastSentDownloadBytes = null;
    _lastSentDownloadPercent = null;
  }
}
