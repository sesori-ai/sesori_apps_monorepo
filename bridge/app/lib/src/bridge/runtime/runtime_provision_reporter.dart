import "dart:io" as io;

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

/// Renders a plugin's runtime-provisioning progress to the terminal.
///
/// On an interactive terminal a download draws a single bar that redraws in
/// place with `\r`; otherwise it prints throttled percentage lines so piped
/// logs stay readable. The common case — a recent runtime already on PATH —
/// emits nothing (resolving and a no-work "ready" are silent), so a healthy
/// startup is not cluttered. Output goes to stderr, like the bridge's other
/// non-gated status messages.
class RuntimeProvisionReporter {
  final StringSink _sink;
  final bool _interactive;

  bool _barActive = false;
  bool _didWork = false;
  int _lastReportedPercent = -1;

  RuntimeProvisionReporter({StringSink? sink, bool? interactive})
    : _sink = sink ?? io.stderr,
      _interactive = interactive ?? io.stderr.hasTerminal;

  static const int _barWidth = 24;

  void report(RuntimeProvisionProgress event) {
    switch (event) {
      case ProvisionResolving():
        // Silent: a quick resolution should leave no trace on the happy path.
        break;
      case ProvisionDownloading(:final receivedBytes, :final totalBytes):
        _reportDownloading(receivedBytes: receivedBytes, totalBytes: totalBytes);
      case ProvisionExtracting():
        _line("Extracting the OpenCode runtime…");
      case ProvisionVerifying():
        _line("Verifying the OpenCode runtime…");
      case ProvisionNotice(:final message):
        _line(message);
      case ProvisionReady():
        if (_didWork) {
          _line("OpenCode runtime ready.");
        } else {
          _finishBar();
        }
      case ProvisionFailed(:final message):
        _line("OpenCode runtime setup failed: $message");
    }
  }

  void _reportDownloading({required int receivedBytes, required int? totalBytes}) {
    _didWork = true;
    if (totalBytes == null || totalBytes <= 0) {
      final megabytes = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
      if (_interactive) {
        _redraw("Downloading the OpenCode runtime…  $megabytes MB");
      }
      return;
    }

    final int percent = ((receivedBytes / totalBytes) * 100).clamp(0, 100).floor();
    if (_interactive) {
      _redraw("Downloading the OpenCode runtime  ${_bar(percent)}  $percent%");
      return;
    }
    // Non-interactive: one line per 10% step (and the final 100%).
    if (percent >= _lastReportedPercent + 10 || percent == 100) {
      _lastReportedPercent = percent;
      _line("Downloading the OpenCode runtime… $percent%");
    }
  }

  String _bar(int percent) {
    final int filled = (_barWidth * percent / 100).round().clamp(0, _barWidth);
    return "[${"=" * filled}${" " * (_barWidth - filled)}]";
  }

  void _redraw(String text) {
    _sink.write("\r$text");
    _barActive = true;
  }

  void _finishBar() {
    if (_barActive) {
      _sink.write("\n");
      _barActive = false;
    }
  }

  void _line(String text) {
    _finishBar();
    _sink.writeln(text);
  }
}
