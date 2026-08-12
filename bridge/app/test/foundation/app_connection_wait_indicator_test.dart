import "dart:io";

import "package:fake_async/fake_async.dart";
import "package:sesori_bridge/src/foundation/app_connection_wait_indicator.dart";
import "package:test/test.dart";

void main() {
  group("AppConnectionWaitIndicator", () {
    test("animates in place and replaces the wait with success", () {
      final out = _CapturingStdout(
        hasTerminal: true,
        supportsAnsiEscapes: true,
        terminalColumns: 80,
      );

      fakeAsync((async) {
        final indicator = AppConnectionWaitIndicator(
          out: out,
          environment: const {"LANG": "en_US.UTF-8"},
          frameInterval: const Duration(milliseconds: 80),
        );

        indicator.start();
        async.elapse(const Duration(milliseconds: 240));
        indicator.stop(connected: true);
      });

      expect("\r".allMatches(out.written).length, greaterThanOrEqualTo(4));
      expect(out.written, contains("⠋ ${AppConnectionWaitIndicator.waitingMessage}"));
      expect(out.written, contains("\r\x1b[2K"));
      expect(out.written, endsWith("✓ ${AppConnectionWaitIndicator.connectedMessage}\n"));
      expect(out.written, isNot(contains(AppConnectionWaitIndicator.staticWaitingMessage)));
    });

    test("uses static ASCII status on a dumb terminal", () {
      final out = _CapturingStdout(
        hasTerminal: true,
        supportsAnsiEscapes: true,
        terminalColumns: 80,
      );

      fakeAsync((async) {
        final indicator = AppConnectionWaitIndicator(
          out: out,
          environment: const {"TERM": "dumb", "LANG": "en_US.UTF-8"},
          frameInterval: const Duration(milliseconds: 80),
        );

        indicator.start();
        async.elapse(const Duration(seconds: 1));
        indicator.stop(connected: true);
      });

      expect(
        out.written,
        "${AppConnectionWaitIndicator.staticWaitingMessage}\n"
        "${AppConnectionWaitIndicator.connectedMessage}\n",
      );
      expect(out.written, isNot(contains("\r")));
    });

    test("uses ASCII animation when unicode glyphs are unavailable", () {
      final out = _CapturingStdout(
        hasTerminal: true,
        supportsAnsiEscapes: true,
        terminalColumns: 80,
      );

      fakeAsync((async) {
        final indicator = AppConnectionWaitIndicator(
          out: out,
          environment: const {"LANG": "C"},
          frameInterval: const Duration(milliseconds: 80),
        );

        indicator.start();
        async.elapse(const Duration(milliseconds: 80));
        indicator.stop(connected: true);
      });

      expect(out.written, contains("\r| ${AppConnectionWaitIndicator.waitingMessage}"));
      expect(out.written, contains("\r/ ${AppConnectionWaitIndicator.waitingMessage}"));
      expect(out.written, endsWith("${AppConnectionWaitIndicator.connectedMessage}\n"));
      expect(out.written, isNot(contains("✓")));
    });

    test("clears animation without success when the session stops", () {
      final out = _CapturingStdout(
        hasTerminal: true,
        supportsAnsiEscapes: true,
        terminalColumns: 80,
      );

      fakeAsync((_) {
        final indicator = AppConnectionWaitIndicator(
          out: out,
          environment: const {"LANG": "en_US.UTF-8"},
          frameInterval: const Duration(milliseconds: 80),
        );

        indicator.start();
        indicator.stop(connected: false);
      });

      expect(out.written, endsWith("\r\x1b[2K"));
      expect(out.written, isNot(contains(AppConnectionWaitIndicator.connectedMessage)));
    });

    test("uses static status when the animated line would wrap", () {
      final out = _CapturingStdout(
        hasTerminal: true,
        supportsAnsiEscapes: true,
        terminalColumns: AppConnectionWaitIndicator.waitingMessage.length + 1,
      );

      fakeAsync((async) {
        final indicator = AppConnectionWaitIndicator(
          out: out,
          environment: const {"LANG": "en_US.UTF-8"},
          frameInterval: const Duration(milliseconds: 80),
        );

        indicator.start();
        async.elapse(const Duration(seconds: 1));
        indicator.stop(connected: false);
      });

      expect(out.written, "${AppConnectionWaitIndicator.staticWaitingMessage}\n");
      expect(out.written, isNot(contains("\r")));
    });

    test("does not retain a timer after the initial write fails", () {
      final out = _ThrowingStdout();

      fakeAsync((async) {
        final indicator = AppConnectionWaitIndicator(
          out: out,
          environment: const {"LANG": "en_US.UTF-8"},
          frameInterval: const Duration(milliseconds: 80),
        );

        expect(indicator.start, returnsNormally);
        expect(async.periodicTimerCount, 0);
        expect(() => indicator.stop(connected: true), returnsNormally);
      });

      expect(out.writeCalls, equals(1));
    });
  });
}

class _CapturingStdout({
    required this.hasTerminal,
    required this.supportsAnsiEscapes,
    required this.terminalColumns,
  }) implements Stdout {
  @override
  final bool hasTerminal;

  @override
  final bool supportsAnsiEscapes;

  @override
  final int terminalColumns;

  final StringBuffer _buffer = StringBuffer();
  String get written => _buffer.toString();

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingStdout() implements Stdout {
  int writeCalls = 0;

  @override
  bool get hasTerminal => true;

  @override
  bool get supportsAnsiEscapes => true;

  @override
  int get terminalColumns => 80;

  @override
  void write(Object? object) {
    writeCalls += 1;
    throw const StdoutException("broken pipe");
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
