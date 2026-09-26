# Step 7 — Regression Docs

Branch `desktop-sign-in/regression-docs`. Regression Coverage and Delivery Rules.

## Scope Delivered

`docs/regression/account-and-onboarding.md` now describes what shipped. It was checked against `client/desktop/lib/features/login/`, `LoginCubit`, `AuthManager`, `LastSignInStorage` and `AuthGateCubit`.

- **Options and layout.** GitHub, Apple and Google go through the browser and email signs in inline. The legal line's links open in the browser. The layout splits at 820 pt, folds to a column with the logo below that, and scrolls at 560×480. While a provider starts, its button spins and the other options are disabled.
- **Handoff card.** The card names the provider and the device and counts down to expiry.
  - Open again reopens the same link without restarting the countdown.
  - Copy link shows an informational confirmation. Finishing the copied link in any browser signs this app in.
  - After a failed launch, the card offers Copy link and Try again.
  - Cancel and choose another way returns to the options.
- **Notices.** Expired, declined and other failures replace the "Sign in" heading, and the options below do not move.
- **Last used and window forward.** Step 6's bullet sat apart, after "Log out asks first". It now follows the other desktop sign-in lines, with the same meaning.
- **Failure signals.**
  - A trapped wait: no Cancel, a card that outlives its link, a failed launch that ends the attempt or offers no link, or options disabled with nothing waiting.
  - A cancelled attempt that later signs in.
  - A declined page or expired link reported as a generic failure.
  - A failure shown under the other sign-in method.
  - The card naming the wrong device.
  - The chip showing or storing account data.

  The two combined lines from steps 2 and 6 are split so that each names one failure.
- **Levels.** L2 names the automated suites. L3 adds every option on the macOS desktop and the plan's macOS row. L4 adds the Windows and Linux rows and the shared email form on the second phone.
- **Exploration, limitations and sources.**
  - Exploration adds the desktop variations.
  - Known Limitations adds the plan's accepted risks: a cancelled attempt's server session lingers, Open again on a used link shows an error page, and "Last used" names no account.
  - Sources adds the desktop code, the test and the plan paths.

No line was stale. Steps 4–6 each described what they shipped, and the Regression Levels had no desktop sign-in coverage.

## Plan Versus Shipped

The document follows the code where it differs from the plan:

- **Step 5.**
  - The notice takes the heading's place instead of a reserved slot.
  - Copy link shows "Link copied to clipboard".
  - A starting provider's button spins.
- **Step 6.** The in-flight provider lives in memory. The document describes "Last used" by its behaviour and names no storage slot.
- **Step 4.**
  - The folded column has the theme background with the logo on top, not a full-bleed aurora.
  - The Apple button shipped after an init probe. The document claims no Apple run; the L3 macOS row covers it.

PLAN.md gains two notes:

- Step 5's deviations, in Architecture section 4.
- Where the document files the matrix: the macOS row and the release-target phone under L3, and the Windows, Linux and second-phone rows under L4. That is where the other desktop documents keep alternate platforms. Retirement still runs the whole matrix.

## Other Documents

These were read and left unchanged, because their sign-in statements still hold:

- `desktop-cockpit-shell.md`: the top 54 px band drags the window on every screen, including the signed-out login. The login column still pads by `PregoTopNavigation.barHeight` (54).
- `desktop-bridge-supervision.md`: signed-out login rendering, browser login and relaunch restore, and a `--hidden` launch staying tray-only. Window forward never fires on a restore.
- `analytics.md`: the desktop's no-op sink.
- `client-persistence.md` and `desktop-distribution.md`: sign out before replacing an old desktop build.

## Evidence

This step changed documentation only, so no Dart suites were run.

- **Links.** PLAN.md's new link to `steps/step-05.md` resolves. The document's existing links to `client-persistence.md`, `desktop-cockpit-shell.md` and `desktop-bridge-supervision.md` are unchanged and resolve. Every path and class named in the new Sources lines exists.
- **Diff.** The diff against `origin/main` is within the 300-line target; the PR body records the exact count.

## Review

`architecture-implementation-review` was not run, because the step touches only docs, the plan and this evidence file.

## Manual

None in this step. Step 8 runs L3 over the matrix. When it moves the plan to `.plan/completed/`, it also updates the document's Sources path `.plan/active/desktop-sign-in/PLAN.md`.
