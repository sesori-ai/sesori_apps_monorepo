# Desktop master-key storage tracker

## Execution

- Status: plan review findings applied; publishing Step 1 next.
- Worktree: user-provided session worktree only; no additional worktrees.
- Branch for Step 1: `sesori/keychain-secure-storage-workflow`.
- Current series total: 5 PRs; one open PR and at most one local successor.
- Authoritative design, estimates, scope and retirement matrix: [PLAN.md](PLAN.md).

| Step | State | PR / evidence |
|---|---|---|
| 1 — Reviewed plan | In progress | Initial review findings applied without re-review; no PR yet. |
| 2 — Pure-Dart encrypted storage boundary | Not started | No production DI change in this step. |
| 3 — Desktop integration and native qualification fixtures | Not started | Remove obsolete per-value native persistence/fixtures. |
| 4 — Regression and distribution documentation | Not started | Add focused feature contract and reconcile existing docs. |
| 5 — Required qualification and retirement | Not started | Keep active until the recorded matrix passes. |

## Decisions

- User clarified that unchanged relaunches do not prompt after Always Allow;
  first-run authorization fan-out is the target.
- Desktop storage is unpublished: no legacy migration or automatic cleanup.
  Existing internal installations sign in once; old Keychain entries remain.
- All existing desktop key/value consumers share the encrypted local store,
  including preferences, avoiding a shared/mobile storage refactor.
- Repository owns one cached master-key initialization and one serialized
  operation tail; raw API owns I/O. No value cache, cross-process lock, broad ACL
  grant, or promise of zero OS prompts.
- Phase-1 shell `SecureStorage` binding lazily resolves the phase-4 core-owned
  repository. One typed scope provider feeds both native adapter and repository;
  all shell-facing contracts are exported through the public barrel.
- Native qualification uses dummy data and isolated state; never reuse or disrupt
  the user's running app, helper, login Keychain, or credentials.

## Evidence

- Planning inspection: current desktop adapter delegates every value to the
  native credential backend; development/release share its current service.
- Release inspection: public v1.9.0 assets contain only bridge archives/checksums;
  desktop regression/distribution docs identify desktop packages as private.
- Read-only inspection: installed macOS app passed `codesign --verify --deep
  --strict`; no app launch or Keychain item read/write was performed.
- Architecture plan review `2359dc5a-26c5-4e8a-a2d4-195b638c8e70`: four concrete
  findings applied; revised plan has not been re-reviewed. The review succeeded
  as a task, but its workflow wrapper failed while emitting an undefined optional
  field. Saved report recovered; no child implementation ran or changed files.
