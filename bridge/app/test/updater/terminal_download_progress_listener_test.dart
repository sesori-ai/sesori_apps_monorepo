import 'dart:async';
import 'dart:io';

import 'package:sesori_bridge/src/updater/formatters/terminal_download_progress_listener.dart';
import 'package:sesori_bridge/src/updater/formatters/update_output_formatter.dart';
import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart' show DownloadProgress;
import 'package:test/test.dart';

class _CapturingStdout implements Stdout {
  _CapturingStdout({required this.hasTerminal});

  @override
  final bool hasTerminal;

  final StringBuffer _buffer = StringBuffer();
  String get written => _buffer.toString();

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A terminal whose writes always fail, simulating a broken pipe / closed
/// terminal mid-download.
class _ThrowingStdout implements Stdout {
  int writeCalls = 0;

  @override
  bool get hasTerminal => true;

  @override
  void write(Object? object) {
    writeCalls++;
    throw Exception('broken pipe');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Feeds [events] through a listener wired to [out] with [style], then drains
/// the stream so all events (and the terminating done) are delivered.
Future<String> _render({
  required UpdateOutputFormatter formatter,
  required _CapturingStdout out,
  required List<DownloadProgress> events,
}) async {
  final controller = StreamController<DownloadProgress>();
  final listener = TerminalDownloadProgressListener(
    progress: controller.stream,
    formatter: formatter,
    out: out,
  );
  events.forEach(controller.add);
  await controller.close();
  await listener.dispose();
  return out.written;
}

void main() {
  group('TerminalDownloadProgressListener', () {
    const colorFormatter = UpdateOutputFormatter(color: true, unicode: true);

    test('draws an animated bar on an interactive terminal and closes at 100%', () async {
      final out = _CapturingStdout(hasTerminal: true);
      final written = await _render(
        formatter: colorFormatter,
        out: out,
        events: const [
          DownloadProgress(receivedBytes: 5, totalBytes: 10),
          DownloadProgress(receivedBytes: 10, totalBytes: 10),
        ],
      );

      expect(written, contains('\r')); // in-place redraw
      expect(written, contains(' 50%'));
      expect(written, contains('100%'));
      expect(written, contains('\u25a0')); // ■ filled cell
      expect(written, endsWith('\n')); // line closed once complete
    });

    test('is silent when the stream has no known total size', () async {
      final out = _CapturingStdout(hasTerminal: true);
      final written = await _render(
        formatter: colorFormatter,
        out: out,
        events: const [DownloadProgress(receivedBytes: 5, totalBytes: null)],
      );

      expect(written, isEmpty);
    });

    test('is silent when the output is not an interactive terminal', () async {
      final out = _CapturingStdout(hasTerminal: false);
      final written = await _render(
        formatter: colorFormatter,
        out: out,
        events: const [
          DownloadProgress(receivedBytes: 5, totalBytes: 10),
          DownloadProgress(receivedBytes: 10, totalBytes: 10),
        ],
      );

      expect(written, isEmpty);
    });

    test('is silent when color is disabled (redirected / NO_COLOR)', () async {
      final out = _CapturingStdout(hasTerminal: true);
      final written = await _render(
        formatter: const UpdateOutputFormatter(color: false, unicode: false),
        out: out,
        events: const [DownloadProgress(receivedBytes: 10, totalBytes: 10)],
      );

      expect(written, isEmpty);
    });

    test('falls back to ASCII bar cells without unicode', () async {
      final out = _CapturingStdout(hasTerminal: true);
      final written = await _render(
        formatter: const UpdateOutputFormatter(color: true, unicode: false),
        out: out,
        events: const [DownloadProgress(receivedBytes: 4, totalBytes: 8)],
      );

      expect(written, contains('#'));
      expect(written, isNot(contains('\u25a0')));
      expect(written, contains(' 50%'));
    });

    test('redraws only when the rendered percent changes', () async {
      final out = _CapturingStdout(hasTerminal: true);
      final written = await _render(
        formatter: colorFormatter,
        out: out,
        events: const [
          DownloadProgress(receivedBytes: 500, totalBytes: 1000),
          DownloadProgress(receivedBytes: 505, totalBytes: 1000), // still 50% — no redraw
          DownloadProgress(receivedBytes: 1000, totalBytes: 1000),
        ],
      );

      expect('\r'.allMatches(written).length, 2);
      expect(written, contains(' 50%'));
      expect(written, contains('100%'));
    });

    test('tolerates a broken pipe: swallows write errors and stops drawing', () async {
      final out = _ThrowingStdout();
      final controller = StreamController<DownloadProgress>();
      final listener = TerminalDownloadProgressListener(
        progress: controller.stream,
        formatter: colorFormatter,
        out: out,
      );

      // Must complete without an uncaught async error escaping the subscription.
      controller.add(const DownloadProgress(receivedBytes: 5, totalBytes: 10));
      controller.add(const DownloadProgress(receivedBytes: 10, totalBytes: 10));
      await controller.close();
      await listener.dispose();

      // After the first failed write the bar is marked terminated, so no further
      // writes are attempted (for later events or the closing newline).
      expect(out.writeCalls, 1);
    });

    test('closes a partially-drawn bar with a newline when the stream ends early', () async {
      final out = _CapturingStdout(hasTerminal: true);
      final written = await _render(
        formatter: colorFormatter,
        out: out,
        events: const [DownloadProgress(receivedBytes: 3, totalBytes: 10)],
      );

      expect(written, contains(' 30%'));
      expect(written, endsWith('\n'));
    });
  });
}
