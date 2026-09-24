import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  Map<String, dynamic> modelJson({required Map<String, dynamic>? fastMode}) => {
    "id": "opus",
    "providerID": "anthropic",
    "name": "Opus",
    "variants": <String>[],
    "fastMode": ?fastMode,
  };

  ProviderModel model({required FastModeSupport? fastMode}) => ProviderModel(
    id: "opus",
    providerID: "anthropic",
    name: "Opus",
    variants: const [],
    defaultVariant: null,
    family: null,
    fastMode: fastMode,
    releaseDate: null,
  );

  group("ProviderModel.fastMode", () {
    test("round-trips every known variant", () {
      for (final fastMode in const [
        FastModeSupport.available(promptCacheTtlSeconds: 3600),
        FastModeSupport.unavailable(reason: FastModeUnavailableReason.spendLimitReached),
        null,
      ]) {
        final original = model(fastMode: fastMode);
        expect(ProviderModel.fromJson(original.toJson()), original);
      }
    });

    test("encodes the variant under the type key", () {
      expect(
        model(fastMode: const FastModeSupport.available(promptCacheTtlSeconds: 1800)).toJson()["fastMode"],
        {"type": "available", "promptCacheTtlSeconds": 1800},
      );
    });

    test("reads an omitted field from an older bridge as no fast mode", () {
      expect(ProviderModel.fromJson(modelJson(fastMode: null)).fastMode, isNull);
    });

    test("reads a variant from a newer bridge as unknown", () {
      expect(
        ProviderModel.fromJson(modelJson(fastMode: {"type": "cooldown", "seconds": 30})).fastMode,
        const FastModeSupport.unknown(),
      );
    });

    test("reads a reason from a newer bridge as unknown", () {
      expect(
        ProviderModel.fromJson(modelJson(fastMode: {"type": "unavailable", "reason": "futureReason"})).fastMode,
        const FastModeSupport.unavailable(reason: FastModeUnavailableReason.unknown),
      );
    });
  });
}
