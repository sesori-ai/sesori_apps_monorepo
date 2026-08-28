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

  test("filters labeled, prefixed, high-entropy, and authorization credentials before tokenization", () {
    const secretAccessKey = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY";
    final terms = calculator.calculate(
      source: ProjectGlossarySource(
        projectName: "AcmeCompiler",
        repositoryName: null,
        trackedPaths: const [
          "config/password=SuperSecretProductionPassword.txt",
          "fixtures/sk_live_abcdefghijklmnopqrstuvwxyz.json",
          "fixtures/authorization_BasicCredentialValue123.json",
        ],
        metadataDocuments: const [
          "AcmeCompiler uses AKIAIOSFODNN7EXAMPLE, q7Vn2Lp9Rk4Tz8Mw6Hx3, and $secretAccessKey.",
          "password=SuperSecretProductionPassword token=aBcDeFgHiJkLmNoPqRsTuVwXyZ",
          '''password = "Correct Horse Battery Staple"''',
          'password = """Topaz Riverstone\nSilverPine"""',
          "token = '''Amber Willow'''",
          '''AWS_SECRET_ACCESS_KEY = "Compound Correct Horse"''',
          '''signing_passphrase = "SigningOrchid SecretGrove"''',
          r'''{"password":"EscapedOrchid \"QuotedMeadow\" HiddenHarbor"}''',
          '''--password "CliOrchid QuotedForest HiddenLake" --framework SafeCliFramework''',
          'authorization = """AuthTriple Juniper Harbor"""',
          '''{"DATABASE_URL":"postgresql://AliceAdmin:hunter2@db.example/acme"}''',
          "server:\n  password: >-\n    YamlOrchid CopperMeadow\n    HiddenCedar\n  framework: SafeFramework",
          "users:\n  - password: |+\n      SequenceOrchid HiddenMeadow\n    framework: SequenceSafeFramework",
          '''{"api_key":"abcdEfghijklmnopqrstuvwxyz"}''',
          "Authorization: Bearer abcDefghijklmnopqrstuvwxyz",
          "Authorization: Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==",
          '''{"Authorization":"CustomScheme customCredentialValue123"}''',
          '''<server><password>CorrectHorse</password><credential value="AttributeSecretValue"/></server>''',
          "<api-key>Azure Falcon Battery</api-key>",
          "<db.password>DottedSecretValue</db.password>",
          "<mvn:server.password>Quartz Meadow Cedar</mvn:server.password>",
          "<dbPassword>CamelSecretValue</dbPassword>",
          "<clientApiKey>Magnolia Garden</clientApiKey>",
          "AcmeCompiler appears again without exposing credentials.",
        ],
      ),
    );

    expect(terms, contains("AcmeCompiler"));
    for (final credentialFragment in [
      "AKIAIOSFODNN7EXAMPLE",
      "q7Vn2Lp9Rk4Tz8Mw6Hx3",
      "wJalrXUtnFEMI",
      "K7MDENG",
      "bPxRfiCYEXAMPLEKEY",
      "SuperSecretProductionPassword",
      "Correct",
      "Horse",
      "Battery",
      "Staple",
      "Topaz",
      "Riverstone",
      "SilverPine",
      "Amber",
      "Willow",
      "Compound",
      "SigningOrchid",
      "SecretGrove",
      "EscapedOrchid",
      "QuotedMeadow",
      "HiddenHarbor",
      "CliOrchid",
      "QuotedForest",
      "HiddenLake",
      "AuthTriple",
      "Juniper",
      "Harbor",
      "AliceAdmin",
      "hunter2",
      "YamlOrchid",
      "CopperMeadow",
      "HiddenCedar",
      "SequenceOrchid",
      "HiddenMeadow",
      "abcdefghijklmnopqrstuvwxyz",
      "BasicCredentialValue123",
      "aBcDeFgHiJkLmNoPqRsTuVwXyZ",
      "abcdEfghijklmnopqrstuvwxyz",
      "abcDefghijklmnopqrstuvwxyz",
      "QWxhZGRpbjpvcGVuIHNlc2FtZQ",
      "customCredentialValue123",
      "CorrectHorse",
      "AttributeSecretValue",
      "Azure",
      "Falcon",
      "Battery",
      "DottedSecretValue",
      "Quartz",
      "Meadow",
      "Cedar",
      "CamelSecretValue",
      "Magnolia",
      "Garden",
    ]) {
      expect(terms, isNot(contains(credentialFragment)));
    }
    expect(terms, containsAll(["SafeFramework", "SequenceSafeFramework", "SafeCliFramework"]));
  });

  test("keeps short symbolic language names", () {
    final terms = calculator.calculate(
      source: ProjectGlossarySource(
        projectName: "AcmeCompiler",
        repositoryName: null,
        trackedPaths: const ["src/C#/Compiler.cs", "src/F#/Parser.fs"],
        metadataDocuments: const ["AcmeCompiler supports C#, F#, and C++."],
      ),
    );

    expect(terms, containsAll(["C#", "F#", "C++"]));
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
