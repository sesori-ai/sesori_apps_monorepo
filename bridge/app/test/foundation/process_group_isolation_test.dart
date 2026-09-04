import "package:sesori_bridge/src/foundation/process_group_isolation.dart";
import "package:test/test.dart";

void main() {
  group("ProcessGroupIsolation", () {
    test("makes the supervised POSIX bridge its own process-group leader", () {
      int? capturedProcessId;
      int? capturedProcessGroupId;
      final ProcessGroupIsolation isolation = ProcessGroupIsolation.forTesting(
        isWindows: false,
        setProcessGroup: ({required int processId, required int processGroupId}) {
          capturedProcessId = processId;
          capturedProcessGroupId = processGroupId;
          return 0;
        },
        readErrorCode: () => throw StateError("errno should not be read"),
      );

      isolation.isolateCurrentProcess();

      expect(capturedProcessId, 0);
      expect(capturedProcessGroupId, 0);
    });

    test("fails loudly when POSIX isolation is rejected", () {
      final ProcessGroupIsolation isolation = ProcessGroupIsolation.forTesting(
        isWindows: false,
        setProcessGroup: ({required int processId, required int processGroupId}) => -1,
        readErrorCode: () => 1,
      );

      expect(
        isolation.isolateCurrentProcess,
        throwsA(
          isA<ProcessGroupIsolationException>().having(
            (error) => error.errorCode,
            "errorCode",
            1,
          ),
        ),
      );
    });

    test("does nothing on Windows where the desktop uses taskkill tree mode", () {
      bool called = false;
      final ProcessGroupIsolation isolation = ProcessGroupIsolation.forTesting(
        isWindows: true,
        setProcessGroup: ({required int processId, required int processGroupId}) {
          called = true;
          return 0;
        },
        readErrorCode: () => 0,
      );

      isolation.isolateCurrentProcess();

      expect(called, isFalse);
    });
  });
}
