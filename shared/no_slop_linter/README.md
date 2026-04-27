# no_slop_linter

A custom Dart linter to prevent sloppy code patterns. Built with `analysis_server_plugin` for native IDE integration and `dart analyze` / `flutter analyze` support.

## Available Rules

| Rule                        | Description                                                                               | Severity |
| --------------------------- | ----------------------------------------------------------------------------------------- | -------- |
| `avoid_bang_operator`       | Prevents usage of the null assertion operator (`!`)                                       | WARNING  |
| `avoid_dynamic_return_type` | Prevents implicit or `dynamic` return types on functions                                  | WARNING  |
| `avoid_implicit_tostring`   | Prevents implicit `toString()` in string interpolation (except String, int, double, bool) | WARNING  |

> **Note:** All rules use WARNING severity to allow incremental cleanup. CI is configured to fail if any changed files contain warnings, encouraging cleanup of files you touch.

## Setup

### 1. Configure Analysis Options

In your `analysis_options.yaml`:

```yaml
plugins:
  no_slop_linter:
    path: modules/no_slop_linter # adjust path as needed
```

### 2. Install Plugin Dependencies

```bash
cd modules/no_slop_linter && dart pub get
```

### 3. Restart IDE Analysis Server

- **VS Code**: `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux) → "Dart: Restart Analysis Server"
- **Android Studio**: File → Invalidate Caches / Restart

## Usage

### IDE

After setup, lint errors appear as squiggles. Hover to see the message and suggestions.

### CLI

```bash
flutter analyze
```

Plugin diagnostics appear with the `no_slop_linter/` prefix in the output.

## CI Integration

### GitHub Actions

```yaml
name: Lint Check

on:
  pull_request:
    branches: [main, develop]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version-file: .tool-versions

      - name: Install dependencies
        run: flutter pub get

      - name: Run analysis
        run: flutter analyze --fatal-infos
```

## Configuration

### Disabling Rules

Rules registered as warnings are enabled by default. Rules registered as lints must be enabled in `analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    no_slop_linter:
      rules:
        avoid_hardcoded_colors: true
```

### Ignoring Specific Lines

```dart
// ignore: no_slop_linter/avoid_bang_operator
final value = nullableValue!;

// ignore_for_file: no_slop_linter/avoid_bang_operator
```

## Why Avoid the Bang Operator?

The bang operator (`!`) asserts a nullable value is non-null. If wrong, it throws a runtime `TypeError`.

**Problems:**

- Runtime exceptions instead of compile-time safety
- Hides potential null-related bugs
- Makes code harder to reason about

**Better alternatives:**

```dart
// Instead of:
final name = user.name!;

// Use null checks:
if (user.name != null) {
  final name = user.name;
}

// Or null-aware operators:
final name = user.name ?? 'Unknown';

// Or pattern matching:
if (user.name case final name?) {
  print(name);
}
```

## Why Avoid Dynamic Return Types?

Functions without explicit return types default to `dynamic`, which bypasses type checking and can hide bugs.

**Examples that trigger this rule:**

```dart
foo() { }              // ERROR: implicit return type
dynamic bar() => 1;    // ERROR: explicit dynamic
get value => _value;   // ERROR: getter without return type
```

**Better alternatives:**

```dart
void foo() { }              // explicit void
int bar() => 1;             // explicit int
String get value => _value; // explicit String
Future<void> baz() async {} // explicit Future<void>
```

## Why Avoid Implicit toString()?

When a non-String value is used in string interpolation, Dart implicitly calls `toString()` on it.

**Allowed types** (predictable `toString()`):

- `String`, `int`, `double`, `bool`

**The real problem:** When a dependency update changes a type from `String` to a class, code using that value in string interpolation (e.g., as a map key) will still compile but silently break at runtime.

```dart
// Before dependency update: userId was String
final cache = <String, Data>{};
cache['user_$userId'] = data;  // worked fine

// After update: userId is now a UserId class
// Code still compiles! But the key is now "user_Instance of 'UserId'"
```

**Other problems:**

- Unexpected output if `toString()` is not properly overridden
- Silent bugs that only manifest at runtime
- Harder to spot in code reviews

**Better alternatives:**

```dart
// These are OK (allowed types):
final count = 42;
final price = 19.99;
final name = "John";
print("$name bought $count items for \$$price");  // OK

// Instead of:
final message = "User: $user";  // ERROR: implicit toString()

// Use explicit conversion:
final message = "User: ${user.toString()}";

// Or better, use a specific formatting method:
final message = "User: ${user.displayName}";
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for maintainer documentation on adding new rules and internal architecture.
