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

ProviderInfo _provider({
  required String id,
  required List<ProviderModel> models,
  String? name,
}) {
  return ProviderInfo(
    id: id,
    name: name ?? id,
    models: {for (final m in models) m.id: m},
    defaultModelID: null,
  );
}

void main() {
  const builder = ModelPickerSectionBuilder();

  List<ModelPickerSection> build({
    required List<ProviderInfo> providers,
    String selectedProviderID = "",
    String selectedModelID = "",
  }) {
    return builder.build(
      providers: providers,
      selectedProviderID: selectedProviderID,
      selectedModelID: selectedModelID,
    );
  }

  group("ModelPickerSectionBuilder.build", () {
    test("sorts providers by name", () {
      final sections = build(
        providers: [
          _provider(id: "z", name: "Zeta", models: [_model(id: "z-1")]),
          _provider(id: "a", name: "Alpha", models: [_model(id: "a-1")]),
        ],
      );
      expect(sections.map((s) => s.providerName), ["Alpha", "Zeta"]);
    });

    test("omits providers without available models", () {
      final sections = build(
        providers: [
          _provider(id: "empty", models: const []),
          _provider(id: "dead", models: [_model(id: "d-1", isAvailable: false)]),
          _provider(id: "alive", models: [_model(id: "a-1")]),
        ],
      );
      expect(sections.map((s) => s.providerID), ["alive"]);
    });

    test("excludes unavailable models", () {
      final sections = build(
        providers: [
          _provider(id: "p", models: [
            _model(id: "kept"),
            _model(id: "dropped", isAvailable: false),
          ]),
        ],
      );
      expect(sections.single.models.map((m) => m.modelID), ["kept"]);
    });

    test("sorts models by release date descending, undated last, ties by name", () {
      final sections = build(
        providers: [
          _provider(id: "p", models: [
            _model(id: "undated-b", name: "B undated"),
            _model(id: "old", name: "Old", releaseDate: DateTime(2024)),
            _model(id: "undated-a", name: "A undated"),
            _model(id: "new", name: "New", releaseDate: DateTime(2026)),
          ]),
        ],
      );
      expect(
        sections.single.models.map((m) => m.modelID),
        ["new", "old", "undated-a", "undated-b"],
      );
    });

    test("marks one representative per family as visible by default", () {
      final sections = build(
        providers: [
          _provider(id: "p", models: [
            _model(id: "sonnet-new", family: "sonnet", releaseDate: DateTime(2026)),
            _model(id: "sonnet-old", family: "sonnet", releaseDate: DateTime(2024)),
            _model(id: "haiku-only", family: "haiku", releaseDate: DateTime(2025)),
          ]),
        ],
      );
      final visible = sections.single.models.where((m) => m.visibleByDefault).map((m) => m.modelID);
      expect(visible, containsAll(["sonnet-new", "haiku-only"]));
      expect(visible, isNot(contains("sonnet-old")));
    });

    test("ignores the provider defaultModelID and picks the newest by date", () {
      final sections = build(
        providers: [
          _provider(
            id: "p",
            models: [
              _model(id: "sonnet-new", family: "sonnet", releaseDate: DateTime(2026)),
              _model(id: "sonnet-old", family: "sonnet", releaseDate: DateTime(2024)),
            ],
          ),
        ],
      );
      final visible = sections.single.models.where((m) => m.visibleByDefault).map((m) => m.modelID);
      expect(visible, contains("sonnet-new"));
      expect(visible, isNot(contains("sonnet-old")));
    });

    test("treats models without a family as their own family", () {
      final sections = build(
        providers: [
          _provider(id: "p", models: [
            _model(id: "lone-a", releaseDate: DateTime(2024)),
            _model(id: "lone-b", releaseDate: DateTime(2026)),
          ]),
        ],
      );
      expect(sections.single.models.every((m) => m.visibleByDefault), isTrue);
    });

    test("keeps the selected model visible by default in the selected provider only", () {
      final providers = [
        _provider(id: "p1", models: [
          _model(id: "shared-new", family: "fam", releaseDate: DateTime(2026)),
          _model(id: "shared-old", family: "fam", releaseDate: DateTime(2024)),
        ]),
        _provider(id: "p2", models: [
          _model(id: "shared-new", family: "fam", releaseDate: DateTime(2026)),
          _model(id: "shared-old", family: "fam", releaseDate: DateTime(2024)),
        ]),
      ];
      final sections = build(
        providers: providers,
        selectedProviderID: "p1",
        selectedModelID: "shared-old",
      );
      final p1 = sections.firstWhere((s) => s.providerID == "p1");
      final p2 = sections.firstWhere((s) => s.providerID == "p2");
      expect(p1.models.firstWhere((m) => m.modelID == "shared-old").visibleByDefault, isTrue);
      expect(p2.models.firstWhere((m) => m.modelID == "shared-old").visibleByDefault, isFalse);
    });

    test("strips the (latest) marker from the display name", () {
      final sections = build(
        providers: [
          _provider(id: "p", models: [
            _model(id: "m", name: "Claude Sonnet (latest)"),
          ]),
        ],
      );
      expect(sections.single.models.single.displayName, "Claude Sonnet");
    });

    test("builds a lowercase search haystack from name, family, id, and provider name", () {
      final sections = build(
        providers: [
          _provider(id: "anthropic", name: "Anthropic", models: [
            _model(id: "claude-4", name: "Claude Sonnet", family: "Sonnet"),
          ]),
        ],
      );
      final searchText = sections.single.models.single.searchText;
      expect(searchText, contains("claude sonnet"));
      expect(searchText, contains("sonnet"));
      expect(searchText, contains("claude-4"));
      expect(searchText, contains("anthropic"));
      expect(searchText, equals(searchText.toLowerCase()));
    });

    test("exposes the family as the entry subtitle", () {
      final sections = build(
        providers: [
          _provider(id: "p", models: [
            _model(id: "with", family: "fam"),
          ]),
        ],
      );
      expect(sections.single.models.single.family, "fam");
    });
  });
}
