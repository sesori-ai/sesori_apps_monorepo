import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/core/platform/io_desktop_application_terminator.dart";

void main() {
  test("forwards the requested exit code to the process seam", () {
    final List<int> exitCodes = <int>[];
    final IoDesktopApplicationTerminator terminator = IoDesktopApplicationTerminator.forTesting(
      exit: ({required int exitCode}) => exitCodes.add(exitCode),
    );

    terminator.terminate(exitCode: 7);

    expect(exitCodes, <int>[7]);
  });
}
