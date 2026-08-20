# Loading Indicators

Indeterminate circular loading states use `PregoActivityIndicator` on every
client surface. The component renders a native activity indicator on iOS,
respects reduced motion, and owns the Flutter fallback used by other targets.
Direct construction of Flutter circular, Cupertino, and refresh spinners is
blocked by `avoid_flutter_spinners`.

Linear refresh bars are progress bars rather than spinners and remain valid.
Pull-to-refresh controls must either render `PregoActivityIndicator` or use a
no-spinner controller when the surface already exposes refresh progress.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated: lint fixtures reject every blocked Flutter spinner constructor and allow only the wrapper fallback suppression and `RefreshIndicator.noSpinner`; widget tests verify Prego fallback, native-view selection, semantics, reduced motion, compact loading states, and pull-to-refresh composition. |
| L2 Routine | Client end to end: exercise full-screen, inline, button, and pull-to-refresh loading states on iOS and one non-iOS client target; confirm each state uses the expected colour and remains correctly sized. |
| L3 Release | Packaged iOS: verify repeated insertion and removal uses the native indicator without stale platform views, clipping defects, or visible animation cadence regressions. |
| L4 Extended | Client end to end: repeat with reduced motion enabled and while moving loading rows into and out of a scroll viewport. |
| L5 Full | No additional coverage. |

## Maintenance Sources

- `client/module_prego/lib/components/loaders/prego_activity_indicator.dart`
- `client/module_prego/test/components/prego_activity_indicator_test.dart`
- `shared/no_slop_linter/lib/src/rules/avoid_flutter_spinners_rule.dart`
- `shared/no_slop_linter/test/rules/avoid_flutter_spinners_test.dart`
