# Contributing to no_slop_linter

This document is for maintainers who want to add new rules or modify existing ones.

## Project Structure

```
no_slop_linter/
├── lib/
│   ├── no_slop_linter.dart    # Plugin entry point
│   └── src/
│       ├── fixes/
│       │   └── add_return_type_fix.dart
│       └── rules/
│           ├── avoid_bang_operator_rule.dart
│           ├── avoid_dynamic_return_type_rule.dart
│           └── avoid_implicit_tostring_rule.dart
├── test/
│   └── rules/                 # Test files using expect_lint
│       ├── avoid_bang_operator_test.dart
│       ├── avoid_dynamic_return_type_test.dart
│       └── avoid_implicit_tostring_test.dart
├── pubspec.yaml
├── README.md                  # Client-facing docs
└── CONTRIBUTING.md            # This file
```

## Adding a New Rule

### 1. Create the Rule File

Create `lib/src/rules/your_rule_name.dart`:

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class YourRuleName extends DartLintRule {
  const YourRuleName() : super(code: _code);

  static const _code = LintCode(
    name: 'your_rule_name',
    problemMessage: 'Describe what is wrong.',
    correctionMessage: 'Describe how to fix it.', // optional
    errorSeverity: DiagnosticSeverity.ERROR, // ERROR, WARNING, or INFO
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Register callbacks for AST nodes you want to analyze
    context.registry.addPostfixExpression((node) {
      // Check conditions and report errors
      if (/* your condition */) {
        reporter.atNode(node, _code);
        // or: reporter.atToken(node.someToken, _code);
      }
    });
  }
}
```

### 2. Register the Rule

Add to `lib/no_slop_linter.dart`:

```dart
import 'src/rules/your_rule_name.dart';

class _NoSlopLinterPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        const AvoidBangOperatorRule(),
        const YourRuleName(), // Add here
      ];
}
```

### 3. Update Documentation

Add the rule to the table in `README.md`:

```markdown
| `your_rule_name` | Description | ERROR |
```

## Adding Quick Fixes

Quick fixes allow users to automatically resolve lint errors in their IDE.

### 1. Create the Fix File

Create `lib/src/fixes/your_fix_name.dart`:

```dart
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

class YourFixName extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    Diagnostic analysisError,
    List<Diagnostic> others,
  ) {
    context.registry.addFunctionDeclaration((node) {
      // Only process if this node matches the error location
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      // Get information needed for the fix
      final fragment = node.declaredFragment;
      if (fragment == null) return;

      // Create the fix
      final changeBuilder = reporter.createChangeBuilder(
        message: 'Your fix description',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Insert text at a position
        builder.addSimpleInsertion(offset, 'text to insert');

        // Or replace text
        // builder.addSimpleReplacement(
        //   SourceRange(offset, length),
        //   'replacement text',
        // );
      });
    });
  }
}
```

### 2. Register the Fix with the Rule

In your rule file, override `getFixes()`:

```dart
import '../fixes/your_fix_name.dart';

class YourRuleName extends DartLintRule {
  // ...

  @override
  List<Fix> getFixes() => [YourFixName()];

  // ...
}
```

## Common AST Node Callbacks

The `context.registry` provides callbacks for various AST nodes:

```dart
// Expressions
context.registry.addPostfixExpression((node) { });       // e.g., value!
context.registry.addPrefixExpression((node) { });        // e.g., !value
context.registry.addBinaryExpression((node) { });        // e.g., a + b
context.registry.addMethodInvocation((node) { });        // e.g., foo.bar()
context.registry.addInterpolationExpression((node) { }); // e.g., ${value} in strings

// Declarations
context.registry.addClassDeclaration((node) { });
context.registry.addFunctionDeclaration((node) { });
context.registry.addVariableDeclaration((node) { });

// Statements
context.registry.addIfStatement((node) { });
context.registry.addForStatement((node) { });
context.registry.addReturnStatement((node) { });
```

See [analyzer AST documentation](https://pub.dev/documentation/analyzer/latest/dart_ast_ast/dart_ast_ast-library.html) for all node types.

## Reporting Errors

```dart
// Report at a specific node (highlights the entire node)
reporter.atNode(node, _code);

// Report at a specific token (highlights just the token)
reporter.atToken(node.operator, _code);

// Report at a specific offset/length
reporter.atOffset(
  offset: node.offset,
  length: node.length,
  errorCode: _code,
);
```

## Severity Levels

Set in `LintCode.errorSeverity`:

| Severity | IDE Display | CLI Output | Use Case |
|----------|-------------|------------|----------|
| `ERROR` | Red squiggle | `ERROR` | Must fix, blocks CI |
| `WARNING` | Yellow squiggle | `WARNING` | Should fix |
| `INFO` | Blue squiggle | `INFO` | Suggestion |

## Testing Rules

Tests use `custom_lint_core`'s `testAnalyzeAndRun` method for proper unit testing.

### 1. Create a Test File

Create `test/rules/your_rule_name_test.dart`:

```dart
import 'dart:io' as io;

import 'package:no_slop_linter/src/rules/your_rule_name.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

io.File writeToTemporaryFile(String content, io.Directory tempDir) {
  final file = io.File(p.join(tempDir.path, 'test_file.dart'))
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
  return file;
}

void main() {
  late io.Directory tempDir;

  setUp(() {
    tempDir = io.Directory.systemTemp.createTempSync('lint_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('YourRuleName', () {
    const rule = YourRuleName();

    test('reports error for bad code', () async {
      final file = writeToTemporaryFile('''
void main() {
  badCode();
}
''', tempDir);

      final errors = await rule.testAnalyzeAndRun(file);

      expect(errors, hasLength(1));
      expect(errors.first.diagnosticCode.name, 'your_rule_name');
    });

    test('does not report error for good code', () async {
      final file = writeToTemporaryFile('''
void main() {
  goodCode();
}
''', tempDir);

      final errors = await rule.testAnalyzeAndRun(file);

      expect(errors, isEmpty);
    });
  });
}
```

### 2. Run Tests

```bash
cd modules/no_slop_linter
dart test
```

### 3. Existing Test Files

```
test/rules/
├── avoid_bang_operator_test.dart
├── avoid_dynamic_return_type_test.dart
└── avoid_implicit_tostring_test.dart
```

## Useful Resources

- [custom_lint documentation](https://pub.dev/packages/custom_lint)
- [custom_lint_builder API](https://pub.dev/documentation/custom_lint_builder/latest/)
- [analyzer package](https://pub.dev/packages/analyzer)
- [AST Explorer for Dart](https://dartpad.dev) (use `print(node.runtimeType)` to explore)
