# Product analytics disclosure contract

This file is the review checklist for the public privacy notice and the private
App Store / Play metadata repository. It is not itself a published legal
notice. Product/privacy counsel must approve the final public wording before an
analytics-capable mobile release.

## Account-linked product analytics

Supported release builds may send bounded feature outcomes and canonical screen
categories with a server-derived pseudonymous account key. The Settings control
is enabled only after the authenticated server preference is known. Turning it
off suppresses these events immediately on that installation and synchronizes
the preference for reporting and other supported clients.

The event contract cannot carry source code, prompts, responses, transcripts,
reasoning, filenames or paths, repository/project/session names, coding
provider/model/agent/tool/command names, raw error text, OAuth identity, email,
IP address, or raw/hashed project, session, bridge, device, notification, or
account identifiers.

## Data outside that control

The control does not stop:

- Firebase automatic installation-level events or Firebase's pseudonymous
  installation/device and approximate-location processing;
- the bounded account-less sign-in funnel, which carries only a pinned sign-in
  provider and bounded failure kind;
- account and bridge records required to operate Sesori;
- behavior from an older app version; or
- a remote supported installation until it next establishes authentication or
  explicitly refreshes its preference.

The account-less sign-in funnel has no account key or attempt identifier and
cannot be reliably filtered for internal/test release traffic. It is diagnostic
only and must not be represented as an account conversion metric.

## Retention and deletion limits

- Google Analytics upstream retention is configured to two months.
- The restricted raw BigQuery export expires after 90 days.
- Minimized pseudonymous curated event facts are initially retained for 14
  months; routine product and dashboard viewers cannot access raw datasets or
  pseudonymous keys.
- Account deletion can suppress future account-linked reporting and repeatedly
  remove later keyed uploads. Automatic-only installations that never emitted a
  keyed event cannot be linked back to an account by design, so their upstream
  data follows the two-month limit and an already-exported restricted raw row
  may remain until its 90-day expiration.

## Release checklist

- [ ] Update and publish `https://sesori.com/privacy` with the approved scope,
      identifier, Firebase boundary, retention, synchronization, and deletion
      wording above.
- [ ] Update the private store-metadata repository for both Apple privacy
      details and Google Play Data safety using the same approved claims.
- [ ] Confirm the Settings wording and store/privacy wording describe the same
      control rather than an account-wide or Firebase-wide kill switch.
- [ ] Record product/privacy counsel approval and the first approved app version
      in the private release record.
