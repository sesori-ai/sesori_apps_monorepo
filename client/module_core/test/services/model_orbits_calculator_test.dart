import "package:sesori_dart_core/src/foundation/models/session_options/effort_level.dart";
import "package:sesori_dart_core/src/foundation/models/session_options/model_orbits.dart";
import "package:sesori_dart_core/src/services/model_orbits_calculator.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const _calculator = ModelOrbitsCalculator();
const _fast = FastModeSupport.available(promptCacheTtlSeconds: 3600);

ProviderModel _model({
  required String id,
  String providerID = "openai",
  String? family,
  List<String> variants = const ["low", "medium", "high"],
  bool isAvailable = true,
  FastModeSupport? fastMode = _fast,
  DateTime? releaseDate,
}) => ProviderModel(
  id: id,
  providerID: providerID,
  name: "Name $id",
  variants: variants,
  defaultVariant: null,
  family: family,
  isAvailable: isAvailable,
  fastMode: fastMode,
  releaseDate: releaseDate,
);

ProviderInfo _provider({required List<ProviderModel> models, String id = "openai"}) => ProviderInfo(
  id: id,
  name: id,
  models: {for (final model in models) model.id: model},
  defaultModelID: null,
);

AgentModel _selected({required String modelID, String providerID = "openai", String? variant = "high"}) =>
    AgentModel(providerID: providerID, modelID: modelID, variant: variant);

List<String> _ringIDs(ModelOrbits? orbits) => [...?orbits?.rings.map((ring) => ring.modelID)];

void main() {
  group("ModelOrbitsCalculator rings", () {
    // Catalog order is the plugin's: strongest and newest first. Each family's
    // newest model is its representative, whatever its catalog position.
    final catalog = [
      _provider(
        models: [
          _model(id: "astra", family: "Astra", variants: ["low", "medium", "high", "xhigh"]),
          _model(id: "sol-old", family: "Sol", releaseDate: DateTime(2025)),
          _model(id: "sol-new", family: "Sol", releaseDate: DateTime(2026)),
          _model(id: "terra", family: "Terra"),
          _model(id: "luna", family: "Luna", variants: ["minimal", "low"]),
          _model(id: "mini", family: "Mini"),
        ],
      ),
    ];

    test("are each family's representative, first four families, in catalog order", () {
      final orbits = _calculator.orbits(
        providers: catalog,
        selected: _selected(modelID: "astra"),
      );

      expect(_ringIDs(orbits), ["astra", "sol-new", "terra", "luna"]);
      expect(orbits?.totalModels, 6);
      expect(orbits?.current.modelID, "astra");
      expect(orbits?.currentLevel, EffortLevel.high);
      expect(orbits?.levels, [
        EffortLevel.minimal,
        EffortLevel.low,
        EffortLevel.medium,
        EffortLevel.high,
        EffortLevel.xhigh,
      ]);
      expect(orbits?.allRingsFast, isTrue);
    });

    test("carry each model's name, fast mode, and levels weakest first", () {
      final orbits = _calculator.orbits(
        providers: [
          _provider(
            models: [
              _model(id: "a", variants: ["high", "medium", "low"]),
            ],
          ),
        ],
        selected: _selected(modelID: "a", variant: "medium"),
      );

      final ring = orbits?.current;
      expect(ring?.name, "Name a");
      expect(ring?.fastMode, _fast);
      expect(ring?.levels, const [
        OrbitLevel(
          level: EffortLevel.low,
          variant: SessionVariant(id: "low"),
        ),
        OrbitLevel(
          level: EffortLevel.medium,
          variant: SessionVariant(id: "medium"),
        ),
        OrbitLevel(
          level: EffortLevel.high,
          variant: SessionVariant(id: "high"),
        ),
      ]);
      expect(orbits?.currentLevel, EffortLevel.medium);
    });

    test("give a selected model outside them the fourth place", () {
      final orbits = _calculator.orbits(
        providers: catalog,
        selected: _selected(modelID: "mini"),
      );

      expect(_ringIDs(orbits), ["astra", "sol-new", "terra", "mini"]);
      expect(orbits?.current.modelID, "mini");
    });

    test("keep catalog order when the selected model replaces the fourth", () {
      final orbits = _calculator.orbits(
        providers: catalog,
        selected: _selected(modelID: "sol-old"),
      );

      expect(_ringIDs(orbits), ["astra", "sol-old", "sol-new", "terra"]);
    });

    test("add a selected model outside them when there is room", () {
      final orbits = _calculator.orbits(
        providers: [
          _provider(
            models: [
              _model(id: "sol-old", family: "Sol", releaseDate: DateTime(2025)),
              _model(id: "sol-new", family: "Sol", releaseDate: DateTime(2026)),
              _model(id: "terra", family: "Terra"),
            ],
          ),
        ],
        selected: _selected(modelID: "sol-old"),
      );

      expect(_ringIDs(orbits), ["sol-old", "sol-new", "terra"]);
    });

    test("treat a model without a family as its own family", () {
      final providers = [
        _provider(
          models: [
            for (final id in ["a", "b", "c", "d", "e"]) _model(id: id),
          ],
        ),
      ];

      expect(
        _ringIDs(
          _calculator.orbits(
            providers: providers,
            selected: _selected(modelID: "b"),
          ),
        ),
        [
          "a",
          "b",
          "c",
          "d",
        ],
      );
      expect(
        _ringIDs(
          _calculator.orbits(
            providers: providers,
            selected: _selected(modelID: "e"),
          ),
        ),
        [
          "a",
          "b",
          "c",
          "e",
        ],
      );
    });

    test("leave unavailable models out", () {
      final orbits = _calculator.orbits(
        providers: [
          _provider(
            models: [
              _model(id: "retired", isAvailable: false),
              _model(id: "a"),
            ],
          ),
        ],
        selected: _selected(modelID: "a"),
      );

      expect(_ringIDs(orbits), ["a"]);
      expect(orbits?.totalModels, 1);
    });

    test("report whether every ring has fast mode", () {
      List<ProviderInfo> withSecond({required FastModeSupport? fastMode}) => [
        _provider(
          models: [
            _model(id: "a"),
            _model(id: "b", fastMode: fastMode),
          ],
        ),
      ];

      bool? allFast({required FastModeSupport? fastMode}) => _calculator
          .orbits(
            providers: withSecond(fastMode: fastMode),
            selected: _selected(modelID: "a"),
          )
          ?.allRingsFast;

      expect(
        allFast(fastMode: const FastModeSupport.unavailable(reason: FastModeUnavailableReason.notOnPlan)),
        isTrue,
      );
      expect(allFast(fastMode: null), isFalse);
      expect(allFast(fastMode: const FastModeSupport.unknown()), isFalse);
    });
  });

  group("ModelOrbitsCalculator eligibility", () {
    test("ignores none and gives a model without levels an empty ring", () {
      final orbits = _calculator.orbits(
        providers: [
          _provider(
            models: [
              _model(id: "a"),
              _model(id: "plain", variants: ["none"]),
            ],
          ),
        ],
        selected: _selected(modelID: "plain", variant: null),
      );

      expect(_ringIDs(orbits), ["a", "plain"]);
      expect(orbits?.current.levels, isEmpty);
      expect(orbits?.currentLevel, isNull);
      expect(orbits?.levels, [EffortLevel.low, EffortLevel.medium, EffortLevel.high]);
    });

    test("rejects a catalog with a level off the ladder", () {
      final orbits = _calculator.orbits(
        providers: [
          _provider(
            models: [
              _model(id: "a"),
              _model(id: "b", variants: ["low", "turbo"]),
            ],
          ),
        ],
        selected: _selected(modelID: "a"),
      );

      expect(orbits, isNull);
    });

    test("rejects a catalog where no model reports a level", () {
      final orbits = _calculator.orbits(
        providers: [
          _provider(
            models: [
              _model(id: "a", variants: const []),
              _model(id: "b", variants: ["none"]),
            ],
          ),
        ],
        selected: _selected(modelID: "a", variant: null),
      );

      expect(orbits, isNull);
    });

    test("rejects a catalog with more than one provider offering models", () {
      final orbits = _calculator.orbits(
        providers: [
          _provider(models: [_model(id: "a")]),
          _provider(
            id: "anthropic",
            models: [_model(id: "b", providerID: "anthropic")],
          ),
        ],
        selected: _selected(modelID: "a"),
      );

      expect(orbits, isNull);
    });

    test("ignores a provider without available models", () {
      final orbits = _calculator.orbits(
        providers: [
          _provider(
            id: "anthropic",
            models: [_model(id: "b", providerID: "anthropic", isAvailable: false)],
          ),
          _provider(models: [_model(id: "a")]),
        ],
        selected: _selected(modelID: "a"),
      );

      expect(_ringIDs(orbits), ["a"]);
    });

    test("gives null without a selected model the catalog offers", () {
      final providers = [
        _provider(
          models: [
            _model(id: "a"),
            _model(id: "retired", isAvailable: false),
          ],
        ),
      ];

      expect(_calculator.orbits(providers: providers, selected: null), isNull);
      expect(
        _calculator.orbits(
          providers: providers,
          selected: _selected(modelID: "unlisted"),
        ),
        isNull,
      );
      expect(
        _calculator.orbits(
          providers: providers,
          selected: _selected(modelID: "retired"),
        ),
        isNull,
      );
      expect(
        _calculator.orbits(
          providers: providers,
          selected: _selected(providerID: "other", modelID: "a"),
        ),
        isNull,
      );
    });
  });

  group("EffortLevel.tryParse", () {
    test("reads every ladder id and rejects others", () {
      for (final level in EffortLevel.values) {
        expect(EffortLevel.tryParse(value: level.wireId), level);
      }
      expect(EffortLevel.tryParse(value: "none"), isNull);
      expect(EffortLevel.tryParse(value: "High"), isNull);
    });
  });
}
