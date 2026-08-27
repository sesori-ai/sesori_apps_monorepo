import "package:sesori_bridge/src/repositories/models/project_glossary_source.dart";
import "package:sesori_bridge/src/services/project_glossary_term_calculator.dart";
import "package:test/test.dart";

void main() {
  const calculator = ProjectGlossaryTermCalculator();

  test("prioritizes project and technical path terms while filtering generic and secret-like tokens", () {
    final terms = calculator.calculate(
      source: ProjectGlossarySource(
        projectName: "Sesori-AI",
        repositoryName: "sesori_apps_monorepo",
        trackedPaths: const [
          "lib/src/XChaCha20Poly1305Cipher.dart",
          "lib/src/SesoriRelayClient.dart",
          "lib/src/0123456789abcdef0123456789abcdef.dart",
          "lib/src/project_service.dart",
        ],
        metadataDocuments: const [
          "# Sesori AI\nUses XChaCha20-Poly1305 with GoRouter and Freezed.",
          "Sesori connects the GoRouter client to XChaCha20 tooling.",
        ],
      ),
    );

    expect(terms.first, "Sesori");
    expect(terms, containsAll(["Sesori-AI", "XChaCha20-Poly1305", "GoRouter"]));
    expect(terms, isNot(contains("project")));
    expect(terms, isNot(contains("service")));
    expect(terms.where((term) => term.contains("0123456789abcdef")), isEmpty);
  });

  test("rejects credential prefixes and high-entropy secret-shaped metadata", () {
    const secretAccessKey = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY";
    final terms = calculator.calculate(
      source: ProjectGlossarySource(
        projectName: "AcmeCompiler",
        repositoryName: null,
        trackedPaths: const [
          "config/password=SuperSecretProductionPassword.txt",
          "fixtures/sk_live_abcdefghijklmnopqrstuvwxyz.json",
        ],
        metadataDocuments: const [
          "AcmeCompiler uses AKIAIOSFODNN7EXAMPLE, q7Vn2Lp9Rk4Tz8Mw6Hx3, and $secretAccessKey for examples.",
          "password=SuperSecretProductionPassword token=aBcDeFgHiJkLmNoPqRsTuVwXyZ",
          "AcmeCompiler appears again without exposing credentials.",
        ],
      ),
    );

    expect(terms, contains("AcmeCompiler"));
    expect(terms, isNot(contains("AKIAIOSFODNN7EXAMPLE")));
    expect(terms, isNot(contains("q7Vn2Lp9Rk4Tz8Mw6Hx3")));
    expect(terms, isNot(contains("wJalrXUtnFEMI")));
    expect(terms, isNot(contains("K7MDENG")));
    expect(terms, isNot(contains("bPxRfiCYEXAMPLEKEY")));
    expect(terms, isNot(contains("SuperSecretProductionPassword")));
    expect(terms, isNot(contains("abcdefghijklmnopqrstuvwxyz")));
    expect(terms, isNot(contains("aBcDeFgHiJkLmNoPqRsTuVwXyZ")));
  });

  test("requires repeated metadata evidence for ordinary lowercase prose", () {
    final terms = calculator.calculate(
      source: ProjectGlossarySource(
        projectName: "demo_project",
        repositoryName: null,
        trackedPaths: const [],
        metadataDocuments: const [
          "quasar appears here beside incidentalword",
          "quasar appears in another project manifest",
        ],
      ),
    );

    expect(terms, contains("quasar"));
    expect(terms, isNot(contains("incidentalword")));
  });

  test("returns a deterministic maximum of fifty terms", () {
    final paths = [
      for (var index = 0; index < 80; index++) "lib/DomainTerm${index.toString().padLeft(2, "0")}.dart",
    ];
    final source = ProjectGlossarySource(
      projectName: "AcmeCompiler",
      repositoryName: null,
      trackedPaths: paths,
      metadataDocuments: const [],
    );

    final first = calculator.calculate(source: source);
    final second = calculator.calculate(source: source);

    expect(first, hasLength(ProjectGlossaryTermCalculator.maximumTerms));
    expect(second, first);
    expect(first.first, "AcmeCompiler");
  });
}
