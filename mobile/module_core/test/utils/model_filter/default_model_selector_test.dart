import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

ProviderModel _model({
  required String id,
  String? name,
  String? family,
  DateTime? releaseDate,
  bool isAvailable = true,
}) {
  return ProviderModel(
    id: id,
    providerID: "test-provider",
    name: name ?? id,
    variants: const [],
    family: family,
    isAvailable: isAvailable,
    releaseDate: releaseDate,
  );
}

void main() {
  const selector = DefaultModelSelector();

  group("DefaultModelSelector.pickFromFamily", () {
    test("returns null for an empty group", () {
      expect(
        selector.pickFromFamily(group: const []),
        isNull,
      );
    });

    test("returns null when every model is unavailable", () {
      final group = [
        _model(id: "a", isAvailable: false),
        _model(id: "b", isAvailable: false),
      ];
      expect(
        selector.pickFromFamily(group: group),
        isNull,
      );
    });

    test("prefers a model whose name contains '(latest)' over a newer date", () {
      final group = [
        _model(
          id: "newer",
          name: "Freshly Baked",
          releaseDate: DateTime(2026, 4),
        ),
        _model(
          id: "marked",
          name: "Established Model (latest)",
          releaseDate: DateTime(2025, 11),
        ),
      ];
      final picked = selector.pickFromFamily(group: group);
      expect(picked?.id, "marked");
    });

    test("breaks '(latest)' ties by newest releaseDate", () {
      final group = [
        _model(
          id: "latest-older",
          name: "Older (latest)",
          releaseDate: DateTime(2024, 1),
        ),
        _model(
          id: "latest-newer",
          name: "Newer (latest)",
          releaseDate: DateTime(2025, 6),
        ),
      ];
      final picked = selector.pickFromFamily(group: group);
      expect(picked?.id, "latest-newer");
    });

    test("breaks date ties deterministically by `id` (no unstable sort)", () {
      // Regression: with no `id` tie-breaker, a sort that returns 0 for
      // every comparison (all dates equal) preserves insertion order —
      // which means a model added to the family first wins regardless of
      // its id. With the `id` tie-breaker, the result is deterministic.
      final group = [
        _model(id: "zebra", name: "Zebra", releaseDate: DateTime(2026, 4)),
        _model(id: "alpha", name: "Alpha", releaseDate: DateTime(2026, 4)),
        _model(id: "mango", name: "Mango", releaseDate: DateTime(2026, 4)),
      ];
      final picked = selector.pickFromFamily(group: group);
      expect(picked?.id, "alpha");
    });

    test("breaks null-date ties deterministically by `id`", () {
      final group = [
        _model(id: "zebra", name: "Zebra", releaseDate: null),
        _model(id: "alpha", name: "Alpha", releaseDate: null),
      ];
      final picked = selector.pickFromFamily(group: group);
      expect(picked?.id, "alpha");
    });

    test("falls back to the model with the most recent releaseDate", () {
      final group = [
        _model(id: "old", releaseDate: DateTime(2024, 1)),
        _model(id: "mid", releaseDate: DateTime(2025, 6)),
        _model(id: "newest", releaseDate: DateTime(2026, 4)),
      ];
      final picked = selector.pickFromFamily(group: group);
      expect(picked?.id, "newest");
    });

    test("sorts models with null releaseDate last", () {
      final group = [
        _model(id: "no-date", releaseDate: null),
        _model(id: "newest", releaseDate: DateTime(2026, 4)),
        _model(id: "older", releaseDate: DateTime(2025, 6)),
      ];
      final picked = selector.pickFromFamily(group: group);
      expect(picked?.id, "newest");
    });

    test(
      "ignores the 6-month cutoff — a new model with a stale date still wins",
      () {
        // This is the Kimi bug. With the old cutoff-based filter, a model
        // older than 6 months would be excluded even when nothing newer
        // exists in the same family.
        final group = [
          _model(id: "stale", releaseDate: DateTime(2023, 1)),
        ];
        final picked = selector.pickFromFamily(group: group);
        expect(picked?.id, "stale");
      },
    );

    test("ignores an API defaultModelID pointing to an older model", () {
      // Regression: the upstream provider default is frequently stale.
      // The selector should prefer the newest-by-date model instead.
      final group = [
        _model(id: "newer", releaseDate: DateTime(2026, 4)),
        _model(id: "api-default", releaseDate: DateTime(2025, 6)),
      ];
      final picked = selector.pickFromFamily(group: group);
      expect(picked?.id, "newer");
    });

    test("falls back to the first group member when nothing else matches", () {
      final group = [
        _model(id: "first", releaseDate: null),
        _model(id: "second", releaseDate: null),
      ];
      final picked = selector.pickFromFamily(group: group);
      expect(picked?.id, "first");
    });
  });

  group("DefaultModelSelector.pickFromProvider", () {
    test("returns null when the provider has no available models", () {
      final models = {
        "a": _model(id: "a", isAvailable: false),
      };
      expect(
        selector.pickFromProvider(models: models),
        isNull,
      );
    });

    test("Kimi For Coding: picks K2.6 over K2 Thinking (the original bug)", () {
      // Mirrors the live models.dev entry for `kimi-for-coding`:
      // - kimi-k2-thinking family=kimi-thinking release_date=2025-11
      // - k2p5             family=kimi-thinking release_date=2026-01
      // - k2p6             family=kimi-thinking release_date=2026-04
      //
      // All three are in the same family. The picker previously picked
      // the first model in map iteration order (K2 Thinking). The new
      // selector should pick the newest by date — K2.6.
      final models = {
        "kimi-k2-thinking": _model(
          id: "kimi-k2-thinking",
          name: "Kimi K2 Thinking",
          family: "kimi-thinking",
          releaseDate: DateTime(2025, 11),
        ),
        "k2p5": _model(
          id: "k2p5",
          name: "Kimi K2.5",
          family: "kimi-thinking",
          releaseDate: DateTime(2026, 1),
        ),
        "k2p6": _model(
          id: "k2p6",
          name: "Kimi K2.6",
          family: "kimi-thinking",
          releaseDate: DateTime(2026, 4),
        ),
      };
      final picked = selector.pickFromProvider(models: models);
      expect(picked?.id, "k2p6");
    });

    test(
      "ignores the provider's API defaultModelID and still picks newest by date",
      () {
        final models = {
          "newer": _model(
            id: "newer",
            family: "k2",
            releaseDate: DateTime(2026, 4),
          ),
          "api-default": _model(
            id: "api-default",
            family: "k2",
            releaseDate: DateTime(2025, 11),
          ),
        };
        final picked = selector.pickFromProvider(models: models);
        expect(picked?.id, "newer");
      },
    );

    test(
      "picks the best representative across all families, not just the alphabetically first",
      () {
        final models = {
          "alpha": _model(
            id: "alpha",
            name: "Alpha",
            family: "alpha-family",
            releaseDate: DateTime(2025, 1),
          ),
          "zeta-newer": _model(
            id: "zeta-newer",
            name: "Zeta Newer",
            family: "zeta-family",
            releaseDate: DateTime(2026, 4),
          ),
        };
        final picked = selector.pickFromProvider(models: models);
        // zeta-family is alphabetically later but has the newer model.
        expect(picked?.id, "zeta-newer");
      },
    );

    test(
      "prefers a '(latest)' marker in any family over a newer date in another family",
      () {
        final models = {
          "newer-plain": _model(
            id: "newer-plain",
            name: "Newer Plain",
            family: "plain-family",
            releaseDate: DateTime(2026, 4),
          ),
          "marked-older": _model(
            id: "marked-older",
            name: "Marked Older (latest)",
            family: "marked-family",
            releaseDate: DateTime(2025, 1),
          ),
        };
        final picked = selector.pickFromProvider(models: models);
        expect(picked?.id, "marked-older");
      },
    );

    test(
      "breaks cross-family ties deterministically by id when dates are equal",
      () {
        final models = {
          "zebra": _model(
            id: "zebra",
            name: "Zeta",
            family: "zeta-family",
            releaseDate: DateTime(2026, 4),
          ),
          "alpha": _model(
            id: "alpha",
            name: "Alpha",
            family: "alpha-family",
            releaseDate: DateTime(2026, 4),
          ),
        };
        final picked = selector.pickFromProvider(models: models);
        expect(picked?.id, "alpha");
      },
    );

    test("skips unavailable models when picking the provider default", () {
      final models = {
        "newest": _model(
          id: "newest",
          family: "k2",
          releaseDate: DateTime(2026, 4),
          isAvailable: false,
        ),
        "fallback": _model(
          id: "fallback",
          family: "k2",
          releaseDate: DateTime(2025, 11),
        ),
      };
      final picked = selector.pickFromProvider(models: models);
      expect(picked?.id, "fallback");
    });
  });
}
