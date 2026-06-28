import "dart:async";
import "dart:convert";

import "package:sesori_bridge/src/api/control_secret_api.dart";
import "package:test/test.dart";

void main() {
  group("ControlSecretApi", () {
    test("reads the first line of the input stream as the secret", () async {
      final api = ControlSecretApi(
        input: Stream<List<int>>.fromIterable([utf8.encode("my-secret\nignored\n")]),
      );
      expect(await api.readSecret(), equals("my-secret"));
    });

    test("trims surrounding whitespace from the secret line", () async {
      final api = ControlSecretApi(
        input: Stream<List<int>>.fromIterable([utf8.encode("  spaced-secret  \n")]),
      );
      expect(await api.readSecret(), equals("spaced-secret"));
    });

    test("throws a StateError when the secret line is blank", () async {
      final api = ControlSecretApi(
        input: Stream<List<int>>.fromIterable([utf8.encode("   \n")]),
      );
      await expectLater(api.readSecret(), throwsA(isA<StateError>()));
    });

    test("times out when no line ever arrives", () async {
      final controller = StreamController<List<int>>();
      addTearDown(controller.close);
      final api = ControlSecretApi(input: controller.stream);

      await expectLater(
        api.readSecret(timeout: const Duration(milliseconds: 50)),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
