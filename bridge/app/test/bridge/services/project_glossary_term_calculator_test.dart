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
      maximumTerms: 100,
    );

    expect(terms.first, "Sesori");
    expect(terms, containsAll(["XChaCha20", "Poly1305", "GoRouter", "SesoriRelayClient"]));
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
          '''password = "Correct HorseBattery Staple"''',
          'password = """Topaz Riverstone\nSilverPine"""',
          "token = '''Amber WillowGrove'''",
          '''AWS_SECRET_ACCESS_KEY = "Compound CorrectStallion"''',
          '''signing_passphrase = "SigningOrchid SecretGrove"''',
          '''pass = "PassOrchid HiddenSpruce"''',
          '''--pass "CliPassOrchid HiddenBirch" --bypass BypassFramework''',
          r'''{"password":"EscapedOrchid \"QuotedMeadow\" HiddenHarbor"}''',
          '''--password "CliOrchid QuotedForest HiddenLake" --framework SafeCliFramework''',
          'authorization = """AuthTriple Juniper Harbor"""',
          '''{"DATABASE_URL":"postgresql://AliceAdmin:hunter2@db.example/acme"}''',
          "server:\n  password: >-\n    YamlOrchid CopperMeadow\n    HiddenCedar\n  framework: SafeFramework",
          "users:\n  - password: |+\n      SequenceOrchid HiddenMeadow\n    framework: SequenceSafeFramework",
          "connection:\n  password: PlainOrchid\n    ContinuedQuartz HiddenAspen\n  framework: ContinuedSafeFramework",
          '''{"api_key":"abcdEfghijklmnopqrstuvwxyz"}''',
          "Authorization: Bearer abcDefghijklmnopqrstuvwxyz",
          "Authorization: Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==",
          '''{"Authorization":"CustomScheme customCredentialValue123"}''',
          '''<server><password>CorrectHorse</password><credential value="AttributeSecretValue"/></server>''',
          "<api-key>Azure FalconBattery</api-key>",
          "<db.password>DottedSecretValue</db.password>",
          "<mvn:server.password>Quartz MeadowCedar</mvn:server.password>",
          "<dbPassword>CamelSecretValue</dbPassword>",
          "<clientApiKey>Magnolia GardenGate</clientApiKey>",
          "AcmeCompiler appears again without exposing credentials.",
        ],
      ),
      maximumTerms: 100,
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
      "HorseBattery",
      "Topaz",
      "Riverstone",
      "SilverPine",
      "Amber",
      "Willow",
      "WillowGrove",
      "Compound",
      "CorrectStallion",
      "SigningOrchid",
      "SecretGrove",
      "PassOrchid",
      "HiddenSpruce",
      "CliPassOrchid",
      "HiddenBirch",
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
      "PlainOrchid",
      "ContinuedQuartz",
      "HiddenAspen",
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
      "FalconBattery",
      "DottedSecretValue",
      "Quartz",
      "Meadow",
      "Cedar",
      "MeadowCedar",
      "CamelSecretValue",
      "Magnolia",
      "Garden",
      "GardenGate",
    ]) {
      expect(terms, isNot(contains(credentialFragment)));
    }
    expect(
      terms,
      containsAll([
        "SafeFramework",
        "SequenceSafeFramework",
        "ContinuedSafeFramework",
        "SafeCliFramework",
        "BypassFramework",
      ]),
    );
  });

  test("keeps short symbolic language names", () {
    final terms = calculator.calculate(
      source: ProjectGlossarySource(
        projectName: "AcmeCompiler",
        repositoryName: null,
        trackedPaths: const ["src/C#/Compiler.cs", "src/F#/Parser.fs"],
        metadataDocuments: const ["AcmeCompiler supports C#, F#, and C++."],
      ),
      maximumTerms: 100,
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
          "zustand appears here beside incidentalword",
          "zustand appears in another project manifest",
        ],
      ),
      maximumTerms: 100,
    );

    expect(terms, contains("zustand"));
    expect(terms, isNot(contains("incidentalword")));
  });

  test("drops common English words, their inflections, and generic scaffolding names", () {
    final terms = calculator.calculate(
      source: ProjectGlossarySource(
        projectName: "AcmeCompiler",
        repositoryName: null,
        trackedPaths: const [
          "lib/notifications/deprecated_handlers.dart",
          "lib/notifications/stopped_entries.dart",
          "android/app/src/main/AndroidManifest.xml",
          "android/app/src/main/res/mipmap-hdpi/ic_launcher.png",
        ],
        metadataDocuments: const [
          "For both How and Why: Riverpod keeps running notifications.",
          "For both How and Why: Riverpod keeps running notifications.",
        ],
      ),
      maximumTerms: 100,
    );

    expect(terms, contains("Riverpod"));
    final foldedTerms = terms.map((term) => term.toLowerCase()).toSet();
    for (final common in [
      "for",
      "and",
      "both",
      "how",
      "why",
      "keeps",
      "running",
      "notifications",
      "deprecated",
      "handlers",
      "stopped",
      "entries",
      "androidmanifest",
      "mipmap",
      "hdpi",
      "launcher",
    ]) {
      expect(foldedTerms, isNot(contains(common)));
    }
  });

  test("drops hash, serial, icon-size, and non-ASCII word fragments but keeps technical names", () {
    final terms = calculator.calculate(
      source: ProjectGlossarySource(
        projectName: "AcmeCompiler",
        repositoryName: null,
        trackedPaths: const [
          "docs/p01-overview.md",
          "assets/c4f042.png",
          "icons/Square30x30Logo.png",
          "dist/acme-bridge-darwin-arm64",
        ],
        metadataDocuments: const [
          "Badge ffcb47 in Español, Français, and Übersicht. See README.md for arm64.",
          // "Español" decomposed, as macOS can store it, and names that look like hashes or numbering.
          "Español builds for x64 with D3D11, Ed25519, X25519, and H264. See L23.",
        ],
      ),
      maximumTerms: 100,
    );

    expect(terms, containsAll(["arm64", "x64", "D3D11", "Ed25519", "X25519", "H264"]));
    for (final fragment in [
      "p01",
      "L23",
      "c4f042",
      "Square30x30Logo",
      "acme-bridge-darwin-arm64",
      "ffcb47",
      "Espa",
      "Espan",
      "Fran",
      "ais",
      "bersicht",
      "README.md",
    ]) {
      expect(terms, isNot(contains(fragment)));
    }
  });

  test("keeps a singular term without its plural", () {
    final terms = calculator.calculate(
      source: ProjectGlossarySource(
        projectName: "AcmeCompiler",
        repositoryName: null,
        trackedPaths: const ["lib/keybind.dart", "lib/keybinds/defaults.dart"],
        metadataDocuments: const [],
      ),
      maximumTerms: 100,
    );

    expect(terms, contains("keybind"));
    expect(terms, isNot(contains("keybinds")));
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

    final first = calculator.calculate(source: source, maximumTerms: 50);
    final second = calculator.calculate(source: source, maximumTerms: 50);

    expect(first, hasLength(50));
    expect(second, first);
    expect(first.first, "AcmeCompiler");
  });
}
