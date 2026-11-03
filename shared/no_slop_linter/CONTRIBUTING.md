# Contributing to no_slop_linter

This document is for maintainers who want to add new rules or modify existing ones.
The plugin is built on `analysis_server_plugin`, so the analysis server and
`dart analyze` load it directly.

## Project Structure

```
no_slop_linter/
├── lib/
│   ├── main.dart                  # Plugin entry point: registers every rule and fix
│   └── src/
│       ├── fixes/                 # Quick fixes (ResolvedCorrectionProducer)
│       ├── rules/                 # One file per rule
│       └── utils/no_slop_rule.dart # Shared base classes and test-file exclusion
├── test/
│   ├── fixes/                     # Fix tests (AnalysisRuleFixTest)
│   ├── rules/                     # Rule tests (AnalysisRuleTest)
│   └── test_utils/
├── README.md                      # Rule list and setup
└── CONTRIBUTING.md                # This file
```

## Adding a New Rule

1. Create `lib/src/rules/your_rule_name_rule.dart`. Extend `NoSlopRule` (or
   `NoSlopMultiRule` for several diagnostic codes), declare a `LintCode`, and
   register node processors in `registerRuleProcessors`. Every visitor callback
   starts with `if (rule.isCurrentFileExcluded) return;`.
   `avoid_bang_operator_rule.dart` is a small example to copy.
2. Register the rule in `lib/main.dart` with
   `registry.registerWarningRule(YourRule(ignoreTestFiles: true))`. Warning
   rules are enabled by default; pass `ignoreTestFiles: false` when the rule
   should also check test files.
3. Add the rule to the header list in `lib/main.dart` and to the table in
   `README.md`.

## Adding Quick Fixes

1. Create `lib/src/fixes/your_fix_name.dart` with a class that extends
   `ResolvedCorrectionProducer`, declares a `FixKind`, and implements
   `compute`. `add_return_type_fix.dart` is an example.
2. Register it in `lib/main.dart` with
   `registry.registerFixForRule(YourRule.code, YourFix.new)`.

## Testing

Rule tests extend `AnalysisRuleTest` from `analyzer_testing` and run through
`test_reflective_loader`. Construct the rule with `ignoreTestFiles: false` in
`setUp`, then use `assertDiagnostics` and `assertNoDiagnostics`:

```dart
@reflectiveTest
class YourRuleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = YourRule(ignoreTestFiles: false);
    super.setUp();
  }

  void test_reportsBadCode() async {
    await assertDiagnostics(r'''
dynamic foo;
''', [lint(0, 7)]);
  }
}
```

Fix tests extend `AnalysisRuleFixTest` from `test/test_utils/` and call
`assertHasFix(input, expected, YourFix.new)`.

Run the suite from this directory:

```bash
dart test
```

## Useful Resources

- [analysis_server_plugin package](https://pub.dev/packages/analysis_server_plugin)
- [analyzer package](https://pub.dev/packages/analyzer)
