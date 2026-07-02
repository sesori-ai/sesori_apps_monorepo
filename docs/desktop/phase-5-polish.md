# Phase 5 — Polish (v2)

> Goal: post-v1 polish. Detailed slicing happens when we reach it.

**Per-PR template:** Goal · Scope · Risk · Review-size · **Regression guide** ·
Acceptance · DoD (incl. PLAN.md §9 row + pointer advanced) · Aristotle verdicts ·
Findings log · Plan-deltas.

> **Removed from this phase:** OpenCode detection/onboarding — the bridge now
> auto-provisions OpenCode at startup via `ensureRuntime` (main #322). First-run
> progress + degraded handling already land in v1 (PRs 1.13, 2.16).

---

## PR 5.1 — Multi-window spike (throwaway)
- **Goal:** Validate Flutter multi-window viability (official or
  `desktop_multi_window`) before committing to the popover.
- **Risk:** Med. **Size:** S-M.
- **Regression guide:** throwaway — must not merge runtime changes; findings
  land as docs/plan-deltas only.
- **Acceptance:** a documented go/no-go with a working two-window proof.

## PR 5.2 — Frameless popover window
- **Goal:** VPN-style frameless popover anchored to the tray with hide-on-blur,
  reusing the existing `BridgeControlCubit` state (control logic already shared
  from Phase 2). Sliced into smaller PRs during planning.
- **Risk:** Med. **Size:** M+ (slice).
- **Regression guide:** second window surface over the same cubit. Check: the
  main window keeps working (both surfaces stay consistent when state changes
  while both are visible); tray toggle/quit semantics unchanged; A24 windowed
  fallback unaffected on tray-less Linux; no focus-stealing at hidden autostart.
- **Acceptance:** popover shows status + on/off, anchored + blur-dismiss on 3 OSes.

## PR 5.3 — Richer settings
- **Goal:** Plugin/relay/log-level config, update track, etc. (closes the §1
  "v1 runs default config" non-goal — custom relay/plugin/ports move from
  CLI-only to the GUI here).
- **Risk:** Low-Med. **Size:** M.
- **Regression guide:** settings feed the helper spawn args — bad values become
  a crash-looping helper. Check: invalid relay URL/port values are validated
  before spawn (helper refusal surfaces as a clear error, not a backoff loop);
  changing settings while the bridge runs prompts/apply-on-restart
  deterministically; defaults produce byte-identical spawn args to v1 (no
  accidental behaviour change for untouched settings); settings survive app
  updates.
- **Acceptance:** settings persist + apply.
