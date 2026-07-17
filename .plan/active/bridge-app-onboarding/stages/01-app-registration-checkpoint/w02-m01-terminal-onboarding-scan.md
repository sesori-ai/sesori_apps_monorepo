# S01-W02-M01: Verify Bounded Terminal Onboarding

## Purpose

Advisory manual verification for real terminal QR behavior, the one bounded
registration wait, marker reuse, and logout reset. Automated tests remain
authoritative for HTTP and persistence edge cases.

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
5. Let one wait expire without registering. Confirm startup continues after
   roughly 30 seconds, prints one continuation line, and does not write the
   marker.

### Registration And Reuse

1. Repeat from an unmarked state and register an app token for the same account
   during the wait.
2. Confirm the bridge wakes promptly, prints one success line, writes the marker,
   and continues startup.
3. Restart with the same account. Confirm there is no status request, onboarding
   output, or delay.
4. Authenticate as a different account without reusing the first account's
   marker. Confirm that account receives its own check.

### Logout Reset

1. With a confirmed marker present, cancel a logout when prompted to stop a
   running bridge. Confirm the marker remains.
2. Complete an accepted logout. Confirm tokens and the onboarding marker are
   both cleared.
3. Log in again and confirm onboarding status is checked again.

## Evidence

Record terminal/platform, QR rendered or URL-only, approximate wake/timeout
behavior, same-account silent restart, different-account check, and accepted/
cancelled logout marker behavior. Never record bearer tokens, marker contents,
device tokens, or local user paths.
