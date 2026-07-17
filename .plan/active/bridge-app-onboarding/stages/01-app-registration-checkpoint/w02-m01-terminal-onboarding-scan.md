# S01-W02-M01: Verify Terminal App Onboarding and QR Scanning

## 0. Metadata

- **ID:** S01-W02-M01
- **Type:** Advisory manual checkpoint
- **Stage:** S01 — App Registration Checkpoint
- **Wave:** W02
- **Blocks later waves:** No
- **Automation owner:** None; record separate User and Worker evidence in
  `TRACKER.md`
- **Worker capability:** Partial. A worker can build/run the bridge, use a local
  or deployed auth server, resize the current macOS terminal, capture sanitized
  output, and scan with an available simulator/physical device. The user is best
  placed to provide independent physical-camera and representative Linux/Windows
  terminal/theme evidence.

## 1. Why Automation Is Insufficient

Unit/integration tests prove QR modules, quiet zone, width math, exact URL,
retry/cancellation, and server wake races. They cannot fully prove:

- how real terminal fonts/colors render explicit black/white ANSI half blocks;
- camera focus/contrast against a physical display under dark/light themes;
- common macOS/Linux/Windows terminal width and ANSI behavior;
- the installed app/store handling of the exact public URL; or
- perceived prompt clarity and wake responsiveness during a real same-account
  app sign-in.

This checkpoint supplements but never gates automated verification. Missing
hardware/platform access leaves that party's checkbox unchecked.

## 2. Setup

Use a disposable/test account or safely controlled token state. Do not delete a
primary user's device tokens merely to create the absent state, and never retain
bearer tokens, FCM tokens, auth headers, local paths, or account identifiers in
evidence.

Prerequisites:

1. S01-W01-P01 is deployed to the auth environment under test.
2. S01-W02-P01 is merged or built from its reviewed implementation branch.
3. A standalone bridge invocation with a real interactive stdin/stdout terminal.
4. The selected plugin passes its availability probe.
5. The bridge user currently has no app token, established through normal app
   logout/token deletion on the disposable account.
6. A phone camera or Sesori app capable of opening/scanning the displayed URL.
7. At least one dark and one light terminal theme. Linux/Windows evidence may be
   supplied independently when those hosts are available.

Record only:

- bridge full SHA and auth-server full SHA/deployment identifier;
- bridge OS/architecture and terminal application/version;
- terminal theme category, dimensions, and renderer path observed
  (ANSI+Unicode QR or URL-only);
- app platform/version and approximate timestamps;
- sanitized screenshots/video with account and local details redacted.

## 3. Checklist

### A. Missing-app prompt and exact destination

- [ ] Start the standalone bridge while the disposable account has no token.
- [ ] Confirm authentication/profile and plugin availability complete before the
      onboarding output, while provisioning/plugin startup has not begun.
- [ ] Confirm instructions explicitly say to use/sign in with the same account.
- [ ] Confirm the QR is not visibly clipped and has blank quiet space around all
      edges.
- [ ] Confirm the plain line is exactly
      `https://sesori.com/app/?openStore=true`, including slash/query/case.
- [ ] Scan the QR and independently open/copy the plain URL. Confirm both resolve
      to the same expected Sesori app/store destination.

### B. Durable same-account wake

- [ ] Install/open the app from that destination and sign in to the bridge's
      same disposable account.
- [ ] Confirm the bridge wakes promptly after the app's token registration
      succeeds, without waiting for another client-side polling interval.
- [ ] Confirm one brief success message appears and normal plugin provisioning/
      startup then proceeds exactly once.
- [ ] Restart the bridge while the token remains current. Confirm no onboarding
      QR, URL, presence confirmation, or status warning appears.

### C. Current-run skip and resurfacing

- [ ] Return the disposable account to no-token state through normal app logout.
- [ ] Start again and enter `s` followed by Enter during an active long poll.
- [ ] Confirm the bridge promptly cancels the wait, prints one current-run skip
      confirmation, and continues startup.
- [ ] Restart while still no-token. Confirm onboarding resurfaces.
- [ ] Repeat with ` skip ` and mixed case if practical; confirm trimming and
      case-insensitive alias behavior.
- [ ] Enter an unrelated line once. Confirm it does not skip and the accepted
      aliases are restated without duplicating the full QR.

### D. Terminal rendering matrix

For every available row, scan the QR rather than judging appearance only:

- [ ] macOS common terminal, dark theme, ordinary width.
- [ ] macOS common terminal, light theme, ordinary width.
- [ ] Linux common terminal, dark or light theme.
- [ ] Windows Terminal/PowerShell host, dark or light theme.
- [ ] ANSI+UTF-8 renderer path in both dark and light themes.
- [ ] ANSI-disabled or `NO_COLOR` path omits QR and retains the exact URL.
- [ ] Unicode-disabled/`TERM=dumb` path omits QR and retains the exact URL where
      an interactive test terminal can safely provide that environment.
- [ ] Resize to exactly/comfortably wider than rendered QR and confirm scanning.
- [ ] Resize too narrow and confirm the QR is omitted completely while the exact
      URL and skip instructions remain usable.

Do not claim support for untested terminals. Record skipped rows and available
fallback evidence factually.

### E. Failure cadence and cancellation

Automated tests are authoritative for exact virtual time. If a safe network
failure can be induced without disrupting other work:

- [ ] During onboarding, make the auth endpoint unreachable or return a
      controlled transient failure.
- [ ] Confirm one warning identifies retry in 60 seconds and no repeated request
      or warning occurs before that interval.
- [ ] Enter `skip` during the delay and confirm immediate continuation rather
      than waiting for the minute to end.
- [ ] Restore connectivity/configuration after the check.

Do not wait through repeated real minutes solely for extra confidence and do not
point a production bridge at an untrusted server.

## 4. Expected Evidence

### Worker evidence

- Sanitized command/build SHA summary and auth endpoint environment category.
- Screenshot of rendered prompt + exact URL for each locally available renderer.
- QR scan/open result and app platform used.
- Approximate token-registration-to-success observation.
- Silent existing-token restart and skip/resurface observations.
- Narrow-terminal URL-only evidence.
- Any controlled transient warning/skip observation, or explicit reason omitted.

### User evidence

- Independent physical-camera scan result.
- Available macOS/Linux/Windows terminal/theme/rendering rows and screenshots.
- Confirmation that QR and plain URL resolve identically.
- Same-account sign-in wake and existing-token silent restart observation.
- Prompt clarity/readability and any font/theme discrepancy.

Evidence from one party never checks the other party's tracker box. Redact
account identity, tokens, auth URLs if private, and filesystem paths.

## 5. Pass Criteria

A participating party passes when all safely available checks show:

1. prompted output contains clear same-account guidance and exact URL;
2. every renderer claimed as supported scans successfully with an intact quiet
   zone under the tested theme/terminal;
3. unsafe/too-narrow rendering degrades to URL-only without clipping;
4. durable same-account registration wakes once and existing registration is
   silent on restart;
5. skip cancels current wait/delay, is not persisted, and unrelated input does
   not skip; and
6. any induced transient failure is bounded to one warning/request per fixed
   interval.

A functional mismatch is recorded under `Blockers and Staleness` and `Findings
and Plan Deltas` with a scoped follow-up. Missing platform/device access is
recorded as unexecuted and does not fail/block the plan.

## 6. Cleanup

- Restore the terminal theme, dimensions, color/locale environment, network, and
  auth URL.
- Log out/delete disposable app tokens and account data through normal supported
  flows if no longer needed.
- Remove local screenshots/video containing unredacted account, path, token, or
  endpoint data.
- Stop test bridge/auth processes and remove only disposable build artifacts.
