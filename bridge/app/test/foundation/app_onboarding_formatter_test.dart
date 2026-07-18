import "dart:io";

import "package:qr/qr.dart";
import "package:sesori_bridge/src/foundation/app_onboarding_formatter.dart";
import "package:test/test.dart";

void main() {
  group("AppOnboardingFormatter", () {
    const unicodeEnvironment = {"LANG": "en_US.UTF-8"};

    test("renders the exact medium-correction QR with a four-module quiet zone", () {
      final formatter = AppOnboardingFormatter(
        out: _FakeStdout(supportsAnsiEscapes: true, terminalColumns: 500),
        environment: unicodeEnvironment,
      );
      final expectedImage = QrImage(
        QrCode(
          payload: QrPayload.fromString(AppOnboardingFormatter.appUrl),
          errorCorrectLevel: QrErrorCorrectLevel.medium,
        ),
      );

      final output = formatter.formatDestination();
      final lines = output.split("\n");
      final qrLines = lines.sublist(0, lines.length - 1);

      expect(lines.last, equals(AppOnboardingFormatter.appUrl));
      expect(qrLines, hasLength(((expectedImage.moduleCount + 8) / 2).ceil()));
      for (var renderedRow = 0; renderedRow < qrLines.length; renderedRow++) {
        final cells = _decodeCells(qrLines[renderedRow]);
        expect(cells, hasLength(expectedImage.moduleCount + 8));
        for (var renderedColumn = 0; renderedColumn < cells.length; renderedColumn++) {
          final sourceRow = (renderedRow * 2) - 4;
          final sourceColumn = renderedColumn - 4;
          expect(
            cells[renderedColumn].topDark,
            equals(_expectedDark(expectedImage, row: sourceRow, column: sourceColumn)),
          );
          expect(
            cells[renderedColumn].bottomDark,
            equals(_expectedDark(expectedImage, row: sourceRow + 1, column: sourceColumn)),
          );
        }
        expect(qrLines[renderedRow], endsWith("\x1b[0m"));
      }
      expect(output, contains("\x1b[30m"));
      expect(output, contains("\x1b[37m"));
      expect(output, contains("\x1b[40m"));
      expect(output, contains("\x1b[47m"));
    });

    test("uses QR output only when the known terminal width is sufficient", () {
      final wideOutput = AppOnboardingFormatter(
        out: _FakeStdout(supportsAnsiEscapes: true, terminalColumns: 500),
        environment: unicodeEnvironment,
      ).formatDestination();
      final requiredWidth = _decodeCells(wideOutput.split("\n").first).length;

      expect(
        AppOnboardingFormatter(
          out: _FakeStdout(supportsAnsiEscapes: true, terminalColumns: requiredWidth),
          environment: unicodeEnvironment,
        ).formatDestination(),
        contains("▀"),
      );
      expect(
        AppOnboardingFormatter(
          out: _FakeStdout(supportsAnsiEscapes: true, terminalColumns: requiredWidth - 1),
          environment: unicodeEnvironment,
        ).formatDestination(),
        equals(AppOnboardingFormatter.appUrl),
      );
    });

    test("falls back to the exact URL without ANSI and Unicode support", () {
      expect(
        AppOnboardingFormatter(
          out: _FakeStdout(supportsAnsiEscapes: false, terminalColumns: 500),
          environment: unicodeEnvironment,
        ).formatDestination(),
        equals(AppOnboardingFormatter.appUrl),
      );
      expect(
        AppOnboardingFormatter(
          out: _FakeStdout(supportsAnsiEscapes: true, terminalColumns: 500),
          environment: const {"LANG": "C"},
        ).formatDestination(),
        equals(AppOnboardingFormatter.appUrl),
      );
    });

    test("falls back to the exact URL when terminal width is unavailable", () {
      expect(
        AppOnboardingFormatter(
          out: _FakeStdout(supportsAnsiEscapes: true, terminalColumnsError: StateError("no terminal")),
          environment: unicodeEnvironment,
        ).formatDestination(),
        equals(AppOnboardingFormatter.appUrl),
      );
    });
  });
}

List<({bool topDark, bool bottomDark})> _decodeCells(String line) {
  final cellPattern = RegExp("\x1b\\[(30|37)m\x1b\\[(40|47)m▀");
  return [
    for (final match in cellPattern.allMatches(line))
      (
        topDark: match.group(1) == "30",
        bottomDark: match.group(2) == "40",
      ),
  ];
}

bool _expectedDark(QrImage image, {required int row, required int column}) {
  if (row < 0 || column < 0 || row >= image.moduleCount || column >= image.moduleCount) {
    return false;
  }
  return image.isDark(row, column);
}

class _FakeStdout implements Stdout {
  _FakeStdout({
    required this.supportsAnsiEscapes,
    int? terminalColumns,
    this.terminalColumnsError,
  }) : _terminalColumns = terminalColumns;

  @override
  final bool supportsAnsiEscapes;

  final int? _terminalColumns;
  final Object? terminalColumnsError;

  @override
  int get terminalColumns {
    if (terminalColumnsError != null) throw terminalColumnsError!;
    return _terminalColumns!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
