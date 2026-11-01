# Desktop Analytics Tracker

No secrets, raw identifiers or image digests here. Use references to the restricted deployment record, and aggregate
evidence only.

| Step | Repo | Status | PR | Deployed / evidence |
| --- | --- | --- | --- | --- |
| 1 Raise the plan | monorepo | Merged | #2288 | n/a |
| 2 Table and deletion coverage | warehouse | Deployed | sesori-ai/sesori_analytics_platform#17 | Table applied; sweep image rolled; manual sweep passed, 2026-11-01 |
| 3 Auth endpoint | auth | Deployed | sesori-ai/sesori_auth_server#100 | Web deployed; indexes present |
| 4 Auth export | auth | Deployed | sesori-ai/sesori_auth_server#101 | Image rolled after step 2; manual export passed, 2026-11-01 |
| 5 Warehouse union | warehouse | Deployed | sesori-ai/sesori_analytics_platform#18 | Asset applied; assertions passed; real rows not yet through it (drill below) |
| 6 Desktop client, off | monorepo | Merged | #2289 | n/a |
| Pipeline and deletion drill | none | Partly done, 2026-11-01 | n/a | Passed: storage, rejection classes, dedupe, opt-out, export, suppression, cleanup, sweep, removal of one account. Waiting: union, 2026-11-02 |
| 7.a Privacy notice | auth | Merged and live | sesori-ai/sesori_auth_server#99 | Live on both privacy URLs at 2026-10-31 23:15 UTC. Owner approved the wording |
| 7.b Turn it on | monorepo | Merged | #2295 | First internal build carrying it: `v1.11.0-internal.1118`; first stable: build 1118, submitted 2026-11-01 05:42 UTC; release-note line added: |
| 8 Correct the traction copy | website | Waits for the first stable release carrying step 7.b | | |
| 9 Reconcile docs | monorepo | In this PR | | n/a |
| 10 Verify and retire | monorepo | Not started | | Matrix results below |

## Verification results

| Cell | Result | Date (UTC) |
| --- | --- | --- |
| macOS arm64, send | Partly: internal build 1118 stored one `session_message_sent` with `platform = MACOS`. Warehouse stages pending | 2026-11-01 |
| macOS arm64, opt-out | | |
| macOS arm64, dead endpoint | | |
| Linux x64 | | |
| Windows (no app run possible) | | |
| Phone regression | | |
| Date alignment | | |
| QA exclusion | Passed: all 14 password accounts are `@sesori.com`, and the 12 other than the two drill accounts are in the permanent exclusion | 2026-11-01 |
| Bytes | | |
| Website | | |

## Decisions log

- Owner's privacy wording and legal review: the owner approved the wording themselves on 2026-10-31, with no outside review.
- Merged 7.b before the union proof, narrowing the plan's gate: the owner asked to move faster. The drill's rows have an
  Oct 31 source date, so they reach `events_flattened` on Nov 2, before any row from this merge can (Nov 3 or later). A
  union problem therefore shows on test data first. Mongo keeps events for 9 days and each export covers 7, so such a
  problem delays counting without losing events.
- The drill's artificial part: synthetic rows were moved to the last complete UTC day, so that the export took them on
  Nov 1 rather than Nov 2.
- The suppression handoff ran as the operator, because the operator can't impersonate its service account. That identity's
  own access is still unverified.
- Query quotas were raised for the drill on 2026-11-01 and return to 16 GiB per principal and 40 GiB per project after the
  next quota reset.
