import "package:sesori_dart_core/src/capabilities/relay/relay_request_id_generator.dart";
import "package:test/test.dart";

void main() {
  test("generates independent timestamp-counter-random request IDs", () {
    final first = RelayRequestIdGenerator();
    final second = RelayRequestIdGenerator();

    expect(first(), matches(RegExp(r"^[0-9a-f]+-0001[0-9a-f]{4}$")));
    expect(first(), matches(RegExp(r"^[0-9a-f]+-0002[0-9a-f]{4}$")));
    expect(second(), matches(RegExp(r"^[0-9a-f]+-0001[0-9a-f]{4}$")));
  });
}
