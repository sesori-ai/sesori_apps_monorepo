# Phase 5 — Polish (v2)

> Goal: post-v1 polish. Detailed slicing happens when we reach it.

**Per-PR template:** Goal · Scope · Risk · Review-size · Acceptance · DoD ·
Aristotle verdicts · Findings log · Plan-deltas.

> **Removed from this phase:** OpenCode detection/onboarding — the bridge now
> auto-provisions OpenCode at startup via `ensureRuntime` (main #322). First-run
> progress + degraded handling already land in v1 (PRs 1.13, 2.16).

---

## PR 5.1 — Multi-window spike (throwaway)
- **Goal:** Validate Flutter multi-window viability (official or
  `desktop_multi_window`) before committing to the popover.
- **Risk:** Med. **Size:** S-M.
- **Acceptance:** a documented go/no-go with a working two-window proof.

## PR 5.2 — Frameless popover window
- **Goal:** VPN-style frameless popover anchored to the tray with hide-on-blur,
  reusing the existing `BridgeControlCubit` state (control logic already shared
  from Phase 2). Sliced into smaller PRs during planning.
- **Risk:** Med. **Size:** M+ (slice).
- **Acceptance:** popover shows status + on/off, anchored + blur-dismiss on 3 OSes.

## PR 5.3 — Richer settings
- **Goal:** Plugin/relay/log-level config, update track, etc.
- **Risk:** Low-Med. **Size:** M.
- **Acceptance:** settings persist + apply.
