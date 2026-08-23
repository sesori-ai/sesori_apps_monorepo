import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/main.dart";

void main() {
  final buildTime = DateTime.utc(2026, 8, 22, 12);
  final buildEpochSeconds = buildTime.millisecondsSinceEpoch ~/ 1000;

  test("a launch shortly after compilation is inside the window", () {
    expect(
      isWithinBuildWindow(buildEpochSeconds: buildEpochSeconds, now: buildTime.add(const Duration(minutes: 90))),
      isTrue,
    );
  });

  test("the window closes two hours after compilation", () {
    expect(
      isWithinBuildWindow(buildEpochSeconds: buildEpochSeconds, now: buildTime.add(const Duration(hours: 2))),
      isFalse,
    );
  });

  test("an unstamped build is never inside the window", () {
    expect(isWithinBuildWindow(buildEpochSeconds: 0, now: buildTime), isFalse);
  });

  test("a clock behind the stamp is outside the window", () {
    expect(
      isWithinBuildWindow(buildEpochSeconds: buildEpochSeconds, now: buildTime.subtract(const Duration(days: 400))),
      isFalse,
    );
  });
}
