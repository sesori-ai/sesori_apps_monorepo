# S01-W02-M01: Verify Bounded Terminal Onboarding

## Purpose

Advisory manual verification for real terminal QR behavior, the one bounded
registration wait, marker reuse, and logout reset. Automated tests remain
authoritative for HTTP and persistence edge cases.

## Why Manual

Automated tests can verify QR modules and exact output bytes but cannot establish
that a real terminal/font/theme remains camera-scannable or that the destination
opens correctly on a physical/simulated client.

## Executor

The worker may execute the checkpoint when it has a representative terminal and
camera or simulator scanner. Otherwise mark Worker as skipped with the missing
resource in tracker evidence; the user may perform it later. This advisory check
does not block the documentation PR or implementation merge.

## Preconditions

- Auth PR #44 is deployed.
- A W02 bridge build is available.
- A disposable account can register/remove an app token.
- The local onboarding marker can be inspected/cleared in the bridge data
  directory without recording its account id in evidence.

## Checks

### Unmarked Account

1. Start the standalone bridge interactively with no registered app token and no
   local onboarding marker.
2. Confirm setup guidance appears only after authentication and plugin
   availability.
3. Confirm the exact URL is
   `https://sesori.com/app/?openStore=true`, including slash, query, and case.
4. Confirm a QR appears only in a sufficiently wide ANSI+Unicode terminal and
   stays within terminal width. In unsupported/narrow terminals, confirm URL-only
   fallback.
5. Scan the rendered QR with a physical camera or simulator. Confirm it resolves
   to the exact same destination as the plain URL.
6. Let one wait expire without registering. Confirm startup continues after
   roughly 30 seconds, prints one continuation line, and does not write the
   marker.

### Registration And Reuse

1. With a same-account app token already registered but the local marker cleared,
   start the bridge. Confirm the immediate true path is silent, writes the marker,
   and performs no long poll.
2. Clear the disposable token and marker, repeat, and register an app token for
   the same account during the wait.
3. Confirm the bridge wakes promptly, prints one success line, writes the marker,
   and continues startup.
4. Restart with the same account. Confirm there is no status request, onboarding
   output, or delay.

Different-account and different-backend marker isolation remain automated-only:
there is no supported manual account-switch flow that preserves the first marker
without directly manipulating authentication state.

### Logout Reset

1. With a confirmed marker present, cancel a logout when prompted to stop a
   running bridge. Confirm the marker remains.
2. Complete an accepted logout. Confirm tokens and the onboarding marker are
   both cleared.
3. Force marker deletion to fail in a controlled test environment. Confirm
   logout reports failure and tokens remain intact.
4. Log in again after a successful logout and confirm onboarding status is
   checked again.

## Evidence

Record terminal/platform, QR rendered or URL-only, verified scan destination,
immediate/long-poll behavior, same-account silent restart, and accepted/cancelled
logout marker behavior. Never record bearer tokens, marker contents, device
tokens, or local user paths.

## Pass Criteria

- **Pass:** Every executed check matches the expected output, scan destination,
  bounded wait/wake behavior, marker reuse, and logout reset.
- **Fail:** Record the exact mismatching step without secrets and leave the
  Worker checkbox unchecked until corrected and rerun.
- **Skipped:** Record the unavailable terminal/camera/account fixture and leave
  the Worker checkbox unchecked; do not report skipped as passing.
