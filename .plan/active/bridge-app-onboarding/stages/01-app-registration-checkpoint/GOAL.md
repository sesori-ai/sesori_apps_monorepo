# S01: App Registration Checkpoint

## Outcome

An authenticated standalone interactive bridge can determine whether the same
account has a registered Sesori app client. Unmarked accounts are checked once;
only confirmed-absent accounts receive terminal setup guidance and one bounded
30-second registration wait. Confirmed accounts are remembered when marker
persistence succeeds, and matching backend/account markers skip future checks
until logout clears all markers.

## Waves

- **W01:** Auth server exposes authenticated immediate and `wait=true`
  app-client status with durable post-registration wake.
- **W02:** Bridge consumes that endpoint with a bounded QR/URL checkpoint and a
  one-time-per-backend/account local marker.

## Required Behavior

- Current app presence means at least one current device-token row for the
  authenticated user, not historical activation or live app connectivity.
- Existing marked accounts continue silently with no network request.
- Unmarked accounts receive one immediate check.
- Confirmed absence shows same-account instructions, a safe terminal QR when
  possible, and exact URL `https://sesori.com/app/?openStore=true`.
- The bridge performs exactly one 30-second long poll and then continues.
- Confirmed registration writes an opaque per-pair marker derived from normalized
  auth-backend identity plus authenticated JWT `userId`.
- Different account/backend pairs retain independent markers; A -> B -> A checks
  each pair only once.
- Accepted CLI logout clears all markers before tokens; state-clear failure keeps
  tokens and reports failure. Cancelled logout preserves both.
- All bridge-side failures warn once and fail open.
- Supervised, noninteractive, and plugin-unavailable starts do not run the
  checkpoint.

## Scope Boundary

W02 must not consolidate auth HTTP, rename or alter `TokenManager`, change token
persistence/contracts, migrate terminal prompts, add skip input/retries, or touch
shared/client/plugin/relay behavior. Any need to expand beyond the paths declared
in W02 stops implementation for user approval.
