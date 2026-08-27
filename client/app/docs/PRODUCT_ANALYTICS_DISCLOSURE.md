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
- Firebase's release-only account-less sign-in attempt funnel and recommended
  `sign_up`/`login` outcomes, carrying only a pinned sign-in provider, bounded
  failure kind, or pinned authentication method;
- Singular's release-only install/session attribution, SDK-generated device
  identifier, and parameter-free standard authentication conversion events;
  this integration limits advertising identifiers and partner data sharing and
  sets no Sesori user identity;
- account and bridge records required to operate Sesori;
- behavior from an older app version; or
- a remote supported installation until it next establishes authentication or
  explicitly refreshes its preference.

The Firebase account-less authentication catalog has no account key or attempt
identifier and cannot be reliably filtered for internal/test release traffic.
The attempt funnel is diagnostic only. Firebase receives `sign_up` only when
the auth server reports that the operation created the account, and receives
`login` only for a confirmed existing account; a forward-unknown status produces
neither recommended event. Both carry only the pinned `method`. GA4 may use
`sign_up` as an acquisition key event, but it is not the canonical account
registration metric; recurring `login` remains a normal event.

Separately, Singular receives `sng_login` after every successful interactive
authentication and `sng_complete_registration` immediately before it only when
the auth server reports that the operation created the account. Those standard
events carry no provider, account identifier, or other event attributes. Neither
Firebase nor Singular authentication outcomes are sent for session restore,
token refresh, failure, cancellation, or a displaced attempt.

## Singular attribution release gate

The release lanes require and inject Singular's build credentials. The bundled
iOS framework also ships Singular's vendor privacy manifest, which declares a
linked device ID, tracking, and advertising/analytics purposes; runtime flags do
not rewrite that manifest. Product/privacy counsel must therefore review the
binary and store declarations before distributing it and approve Singular's
install/session and SDK-generated device-ID scope, retention, deletion handling,
and corresponding Apple privacy and Google Play Data safety declarations before
a production release. The existing Basic Usage Analytics switch does not
control this attribution SDK.

This scope deliberately removes Android's Google Play Services and AdServices
advertising-ID permissions, sets `limitAdvertisingIdentifiers=true` and
`limitDataSharing=true`, and does not set a custom user ID, log custom Singular
events, attach attributes to the standard authentication events, handle
Singular Links, or register uninstall tokens. Broadening any of those boundaries
requires a separate privacy and product decision.

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
      identifier, Firebase/Singular boundaries, retention, synchronization, and
      deletion wording above.
- [ ] Update the private store-metadata repository for both Apple privacy
      details and Google Play Data safety using the same approved claims.
- [ ] Confirm the Settings wording and store/privacy wording describe the same
      control rather than an account-wide or Firebase-wide kill switch.
- [ ] Review Singular's bundled privacy manifest and update store declarations
      before distributing a binary that contains the SDK.
- [ ] Confirm Firebase receives mutually exclusive `sign_up`/`login` outcomes,
      GA4 marks only `sign_up` as a key event, and neither is used as the
      canonical account-registration count.
- [ ] Confirm Singular retention/deletion settings and record product/privacy
      counsel approval before a production release.
- [ ] Record product/privacy counsel approval and the first approved app version
      in the private release record.
