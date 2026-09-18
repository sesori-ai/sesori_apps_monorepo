# Step 9.c.2b.2 — Scoped project inventory ownership

Delivery 18/22; branch `desktop-ux/project-refresh-ownership`.
Base: #1540 squash `41e019da8bb5af9e23d76888a3a50912a308f26f`, tree
`b5ee109cc3b170700c4697a6390400baf523687a`.

## Scope and ownership

`ProjectInventoryService` owns the existing project reads, retained results, mutations, live projection,
initial connection preparation, reconnect/catalog handling, optimistic renames and analytics lifecycle.
It executes without a mounted Cubit. `ProjectListCubit` only mirrors state and forwards the existing intents;
closing it cancels its subscription, not the service. Mobile owns one service factory per project-route lifetime;
desktop owns one per signed-in cockpit. Desktop's recent inventory is created before project startup can publish.

The original business file moves to `services/project_inventory_service.dart`; the new thin adapter lives at
`cubits/project_inventory/project_list_cubit.dart`. State/outcome models and the shared rename tracker move below
presentation. The state part is regenerated at its new source path and is byte-identical; core DI registers the new
factory. The old composition helper and positional hide API are removed, with in-repository callers updated.
No shim, singleton inventory, second cache, upward request bus, new timer/retry policy, backend rule or persisted
contract is introduced. The existing eleven subscriptions and rename/reconnect/read/catalog fields move intact.
One synchronous subject replaces Bloc storage; one observer subscription is added to the thin Cubit.
The existing loaded-inventory analytics reporter is constructed and disposed by the service; event policy is unchanged.

The typed desktop refresh workflow moves to 9.c.2c / 19/22, alongside its first explicit-refresh control and
busy/failure presentation. It must use these same lower-layer owners and report eventual winning reads, including
later superseding reads; those new result semantics are not claimed here. The series stays at 22 PRs, and no unused
intermediate workflow API lands in this slice. Controls remain a selectively restored successor, not a full stash pop.

## Plan and review

Plan: `/tmp/rose-elephant-project-inventory-ownership-plan.md`, SHA-256
`46bc6fed74bb466aeefaec7ff2ee5577bdb295eeae3e9256b14e668d321f09b6`.
Architecture plan review `3d4e415b-df9f-44c8-a354-319bdb50d41d` approved without findings.
Report: `/tmp/rose-elephant-project-inventory-plan-review.md`, SHA-256
`7fd626aecc48d00b5432608a957ab06c6c06acc85d8141d50fd39717eb521048`.
Implementation architecture review and immutable source/publication checkpoints follow focused verification.
Target: ≤1,400 all-path changed lines; count moved-file edits, generated output, tests and documentation together.

## Verification and execution provenance

The runs below executed in the **uncommitted working tree** based on the squash above, not from a later commit.
The later source checkpoint will identify the delivered implementation; it must not be described as having existed
when these commands ran. Pinned Dart/Flutter 3.47.4. Repository cwd:
`/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/rose-elephant`.

```bash
SDK=/Users/alexandrudochioiu/.asdf/installs/flutter/3.47.4-stable/bin
(cd client/module_core && "$SDK/dart" run build_runner build --delete-conflicting-outputs)
(cd client/module_core && "$SDK/dart" test --reporter=json \
  test/cubits/project_list/project_list_cubit_test.dart \
  test/cubits/shared/optimistic_rename_tracker_test.dart \
  test/services/project_list_service_test.dart test/services/recent_session_inventory_service_test.dart)
(cd client/module_core && "$SDK/dart" test --reporter=json \
  test/cubits/project_list/project_list_cubit_test.dart test/cubits/state_defaults_test.dart)
(cd client/desktop && "$SDK/flutter" test --no-pub --reporter=json \
  test/core/widgets/desktop_cockpit_cubit_provider_test.dart test/core/widgets/desktop_cockpit_shell_test.dart)
(cd client/app && "$SDK/flutter" test --no-pub --reporter=json test/features/project_list)
(cd client/module_app_ui && "$SDK/flutter" test --no-pub --reporter=json \
  test/features/project_list/add_project_dialog_test.dart)
(cd client/module_core && "$SDK/dart" analyze --fatal-infos)
(cd client/app && "$SDK/dart" analyze --fatal-infos)
(cd client/desktop && "$SDK/dart" analyze --fatal-infos)
(cd client/module_app_ui && "$SDK/dart" analyze --fatal-infos)
```

Latest per-suite results: **263 successful cases**, without double-counting retries:

| Area | Successful cases | Saved JSON report under `/tmp/` |
|---|---:|---|
| Project behavior/lifetime and state defaults | 92 + 3 | `rose-elephant-project-inventory-core-sync-tests.jsonl` |
| Rename tracker, project helper, recent inventory | 4 + 6 + 21 | `rose-elephant-project-inventory-core-tests.jsonl` |
| Desktop cockpit and both-provider ownership | 37 + 1 | `rose-elephant-project-inventory-desktop-tests.jsonl` |
| Mobile project screens, menus, scan and analytics | 80 | `rose-elephant-project-inventory-app-final-tests.jsonl` |
| Shared add-project dialog | 19 | `rose-elephant-project-inventory-module_app_ui-final-tests.jsonl` |

The original core batch failed eight project assertions: an asynchronous subject delayed optimistic changes and
completed-read state relative to the old synchronous Cubit. Using synchronous service publication fixes that semantic
regression; all 92 project cases then pass, including the 90 existing cases and two direct ownership/lifetime cases.
The 31 unaffected cases in the first batch passed and were not rerun; that batch's overall exit was not successful.
A missing `FailureReporter` import in the mobile fake-DI helper was corrected; the final mobile command exits 0.
All final named commands exit 0 with `done.success: true`, except that explicitly identified initial core batch.

Core, desktop, mobile and shared UI analyzers pass. Owning generation succeeds with normal external platform/auth
registration warnings; it removes the old generated state path and writes the new one. Logs/command receipts use
`/tmp/rose-elephant-project-inventory-*`. The desktop/mobile/shared final receipts also record cwd, command, base,
exit, per-suite counts and report hashes. Counts come from non-hidden `testDone` events, including platform variants.

The headless cases prove initial execution without a Cubit, retained replay, live updates after consumer closure,
replacement consumers and disposal fencing a pending result/unseen seeding. The fake desktop provider fixture proves
recent admission exists before project startup publication, both scoped owners are shared, and exit disposes both.

## Boundaries

No intended user-visible, analytics-policy, database or transport change. No real app, bridge/helper, auth/preferences,
secure storage, device, registration, production database or protected app smoke operation ran.
Automated checks and architecture review are not native/live qualification; that matrix remains outstanding.
