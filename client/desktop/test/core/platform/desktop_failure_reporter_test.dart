import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/core/platform/desktop_failure_reporter.dart";

void main() {
  test("keeps failure context and error details while redacting information values", () async {
    String? loggedMessage;
    Object? loggedError;
    StackTrace? loggedStackTrace;
    final StackTrace stackTrace = StackTrace.current;
    final StateError error = StateError("transport failed");
    final reporter = DesktopFailureReporter.forTesting(
      logSink: ({required String message, required Object? error, required StackTrace? stackTrace}) {
        loggedMessage = message;
        loggedError = error;
        loggedStackTrace = stackTrace;
      },
    );

    await reporter.recordFailure(
      error: error,
      stackTrace: stackTrace,
      uniqueIdentifier: "sse_parse_failure:SesoriSessionUpdated",
      fatal: false,
      reason: "Failed to parse event",
      information: const <Object>["prompt text must not be logged", "project-id"],
    );

    expect(loggedMessage, contains("sse_parse_failure:SesoriSessionUpdated"));
    expect(loggedMessage, contains("String(length=30)"));
    expect(loggedMessage, isNot(contains("prompt text must not be logged")));
    expect(loggedMessage, isNot(contains("project-id")));
    expect(loggedError, same(error));
    expect(loggedStackTrace, same(stackTrace));
  });

  test("bounds and sanitizes free-form context", () async {
    String? loggedMessage;
    final reporter = DesktopFailureReporter.forTesting(
      logSink: ({required String message, required Object? error, required StackTrace? stackTrace}) {
        loggedMessage = message;
      },
    );

    reporter.log(message: "line one\nline two");

    expect(loggedMessage, "Failure reporter log: line_one_line_two");
  });
}
