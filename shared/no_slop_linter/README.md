# no_slop_linter

A custom Dart linter to prevent sloppy code patterns. Built with `analysis_server_plugin` for native IDE integration and `dart analyze` / `flutter analyze` support.

## Available Rules

Every rule is registered as a warning rule, so it is enabled wherever the plugin is loaded. The analyzer reports the diagnostics at INFO severity, and `dart analyze --fatal-infos` fails on them.

| Rule | Description |
| ---- | ----------- |
| `avoid_as_cast` | Prevents `as` casts; use `is` checks or patterns |
| `avoid_bang_operator` | Prevents the null assertion operator (`!`) |
| `avoid_dynamic_return_type` | Prevents implicit or `dynamic` return types on functions |
| `avoid_flutter_spinners` | Prevents direct Flutter spinner widgets; use `PregoActivityIndicator` |
| `avoid_implicit_tostring` | Prevents implicit `toString()` in string interpolation. Exempt: `String`, `int`, `double`, `bool` and `dynamic` values, explicit `.toString()` calls, and interpolations inside `logt`/`logd` calls |
| `avoid_legacy_flutter_design_imports` | Prevents SDK Material and Cupertino imports; use the standalone UI packages |
| `avoid_material_icons` | Prevents Material `Icons` glyphs; use `TablerRegular` or `TablerSolid` |
| `avoid_mutable_class_fields` | Prevents non-final public instance fields |
| `avoid_navigator_of` | Prevents direct `Navigator` usage; use GoRouter |
| `avoid_raw_go_router` | Prevents raw GoRouter navigation and direct GoRouter access; use the typed route extensions |
| `avoid_raw_modal_presenters` | Prevents `showDialog`, `showModalBottomSheet` and other SDK modal presenters; use `showPregoModal` |
| `avoid_string_literals_in_widgets` | Prevents hardcoded strings in `Text` widgets; use localization |
| `prefer_edge_insets_directional` | Enforces `EdgeInsetsDirectional` for RTL support |
| `prefer_exhaustive_switch` | Prevents `default` cases in switches over enums and sealed classes |
| `prefer_required_named_parameters` | Enforces required named parameters for multi-argument functions |
| `prefer_specific_type` | Prevents `Object` and `dynamic`. Exempt: `Map<String, dynamic>`/`Map<String, Object?>` JSON maps; `dynamic`/`Object?` parameters named `json`; `Object`/`Object?` declarations whose names all contain `error` or `cause` (`dynamic error` is still reported); `on Object catch`; generic bounds; overrides, `external` declarations and inline callback parameters |
| `prefer_text_align_directional` | Enforces `TextAlign.start`/`end` instead of `left`/`right` for RTL support |

`avoid_bang_operator` and `avoid_legacy_flutter_design_imports` also check test files. The other rules skip files under `test/` and files ending in `_test.dart`.

## Setup

### 1. Configure Analysis Options

In the `analysis_options.yaml` at the root of the workspace or package:

```yaml
plugins:
  no_slop_linter:
    path: ../shared/no_slop_linter # relative to this analysis_options.yaml
```

The analysis server resolves the plugin's dependencies itself, so packages do not need a `no_slop_linter` dependency.

### 2. Restart IDE Analysis Server

- **VS Code**: `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux) → "Dart: Restart Analysis Server"
- **Android Studio**: File → Invalidate Caches / Restart

## Usage

### IDE

After setup, lint errors appear as squiggles. Hover to see the message and suggestions.

### CLI

```bash
dart analyze --fatal-infos
```

Use `dart analyze`: `flutter analyze` hides the plugin's INFO diagnostics. Plugin diagnostics appear with the rule name in the output.

## Configuration

### Disabling Rules

Turn a rule off for every file under an `analysis_options.yaml` that loads the plugin:

```yaml
plugins:
  no_slop_linter:
    path: ../shared/no_slop_linter
    diagnostics:
      avoid_string_literals_in_widgets: false
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
