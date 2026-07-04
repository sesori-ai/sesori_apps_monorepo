import 'dart:async';
import 'dart:io';

import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart' show DownloadProgress;

import 'update_output_formatter.dart';

/// Subscribes to a download's [DownloadProgress] stream and renders an in-place
/// `■`/`･` progress bar to [_out] (stderr), matching the installer's download
/// bar (`lib/ui.js`).
///
/// Owns its subscription lifecycle: it subscribes on construction and stops on
/// [dispose] or when the stream ends. It draws only on an interactive terminal
/// with color enabled and a known total size; otherwise it silently drains the
/// stream, so callers need no capability branching. The bar animates on a single
/// carriage-returned line and is closed with a newline exactly once — when the
/// download reaches 100%, or the stream ends/errors after any draw — so later
/// output starts on a fresh line.
class TerminalDownloadProgressListener {
  TerminalDownloadProgressListener({
    required Stream<DownloadProgress> progress,
    required UpdateOutputFormatter formatter,
    required Stdout out,
  }) : _formatter = formatter,
       _out = out {
    _subscription = progress.listen(
      _onProgress,
      onDone: _terminateLine,
      onError: (_) => _terminateLine(),
      cancelOnError: false,
    );
  }

  static const int _barCells = 32;

  final UpdateOutputFormatter _formatter;
  final Stdout _out;
  late final StreamSubscription<DownloadProgress> _subscription;

  bool _drew = false;
  bool _terminated = false;

  /// Closes any in-progress bar line and cancels the subscription.
  Future<void> dispose() async {
    _terminateLine();
    await _subscription.cancel();
  }

  void _onProgress(DownloadProgress progress) {
    if (_terminated || !_enabled) {
      return;
    }
    final int? total = progress.totalBytes;
    if (total == null || total <= 0) {
      return;
    }
    final int percent = ((progress.receivedBytes * 100) ~/ total).clamp(0, 100);
    final int filled = (percent * _barCells) ~/ 100;
    final String bar = _formatter.progressBar(filledCells: filled, totalCells: _barCells);
    final String pct = percent.toString().padLeft(3);
    _out.write('\r      $bar $pct%');
    _drew = true;
    if (progress.receivedBytes >= total) {
      _terminateLine();
    }
  }

  /// Writes the closing newline once, after any draw, so subsequent output
  /// starts on a fresh line instead of the animated bar.
  void _terminateLine() {
    if (_drew && !_terminated) {
      _out.write('\n');
      _terminated = true;
    }
  }

  bool get _enabled => _formatter.color && _hasTerminal;

  bool get _hasTerminal {
    try {
      return _out.hasTerminal;
    } catch (_) {
      // Fake/exotic stdout streams (tests, unusual platforms) may not implement
      // the terminal probe; treat them as non-interactive so no bar is drawn.
      return false;
    }
  }
}
