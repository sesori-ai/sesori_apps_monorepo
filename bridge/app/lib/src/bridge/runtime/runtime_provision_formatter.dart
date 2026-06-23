import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show
        ProvisionDownloading,
        ProvisionExtracting,
        ProvisionFailed,
        ProvisionNotice,
        ProvisionReady,
        ProvisionResolving,
        ProvisionVerifying,
        RuntimeProvisionProgress;

/// Converts a plugin's runtime-provisioning progress into terminal text.
///
/// Returns the exact string the caller should write to stderr for each event,
/// or `null` when an event should produce no output. On an interactive terminal
/// a download is a single bar that redraws in place with `\r`; otherwise it is
/// throttled percentage lines so piped logs stay readable. The common case — a
/// recent runtime already on PATH — formats to nothing (resolving and a no-work
/// "ready" are silent), so a healthy startup is not cluttered. The formatter
/// owns only redraw bookkeeping; the caller owns the I/O.
class RuntimeProvisionFormatter {
  final bool _interactive;

  bool _barActive = false;
  bool _didWork = false;
  int _lastReportedPercent = -1;

  RuntimeProvisionFormatter({required bool interactive}) : _interactive = interactive;

  static const int _barWidth = 24;

  String? format(RuntimeProvisionProgress event) {
    switch (event) {
      case ProvisionResolving():
        // Silent: a quick resolution should leave no trace on the happy path.
        return null;
      case ProvisionDownloading(:final receivedBytes, :final totalBytes):
        return _downloading(receivedBytes: receivedBytes, totalBytes: totalBytes);
      case ProvisionExtracting():
        return _line("Extracting the OpenCode runtime…");
      case ProvisionVerifying():
        return _line("Verifying the OpenCode runtime…");
      case ProvisionNotice(:final message):
        return _line(message);
      case ProvisionReady():
        return _didWork ? _line("OpenCode runtime ready.") : _finishBar();
      case ProvisionFailed(:final message):
        return _line("OpenCode runtime setup failed: $message");
    }
  }

  String? _downloading({required int receivedBytes, required int? totalBytes}) {
    _didWork = true;
    if (totalBytes == null || totalBytes <= 0) {
      if (!_interactive) {
        return null;
      }
      final megabytes = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
      _barActive = true;
      return "\rDownloading the OpenCode runtime…  $megabytes MB";
    }

    final int percent = ((receivedBytes / totalBytes) * 100).clamp(0, 100).floor();
    if (_interactive) {
      _barActive = true;
      return "\rDownloading the OpenCode runtime  ${_bar(percent)}  $percent%";
    }
    // Non-interactive: one line per 10% step (and the final 100%).
    if (percent >= _lastReportedPercent + 10 || percent == 100) {
      _lastReportedPercent = percent;
      return _line("Downloading the OpenCode runtime… $percent%");
    }
    return null;
  }

  String _bar(int percent) {
    final int filled = (_barWidth * percent / 100).round().clamp(0, _barWidth);
    return "[${"=" * filled}${" " * (_barWidth - filled)}]";
  }

  /// A status line, prefixed with a newline that closes an in-progress redraw
  /// bar when one is active.
  String _line(String text) {
    final String prefix = _finishBar() ?? "";
    return "$prefix$text\n";
  }

  /// The newline that finalizes an active redraw bar, or `null` when no bar is
  /// in progress.
  String? _finishBar() {
    if (_barActive) {
      _barActive = false;
      return "\n";
    }
    return null;
  }
}
