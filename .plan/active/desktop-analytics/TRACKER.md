# Desktop Analytics Tracker

No secrets, raw identifiers or image digests here. Use references to the restricted deployment record, and aggregate
evidence only.

| Step | Repo | Status | PR | Deployed / evidence |
| --- | --- | --- | --- | --- |
| 1 Raise the plan | monorepo | Not started | | n/a |
| 2 Table and deletion coverage | warehouse | Not started | | Table applied; sweep image rolled; manual sweep passed |
| 3 Auth endpoint | auth | Not started | | Web deployed; indexes present |
| 4 Auth export | auth | Not started | | Image rolled after step 2; manual export passed |
| 5 Warehouse union | warehouse | Not started | | Asset applied; assertions passed; watermark advanced |
| 6 Desktop client, off | monorepo | Implemented, capability off | This PR | n/a |
| Pipeline and deletion drill | none | Waits for steps 2-5 deployed | n/a | Result and date: |
| 7 Turn it on | monorepo | Blocked on steps 2-6, the drill, the owner's privacy decision and the live notice | | First internal build carrying it: ; first stable: |
| 8 Say the traction page counts the desktop app | website | Waits for the first stable release carrying step 7 | | Date used: |
| 9 Reconcile docs | monorepo | Not started | | n/a |
| 10 Verify and retire | monorepo | Not started | | Matrix results below |

## Verification results

| Cell | Result | Date (UTC) |
| --- | --- | --- |
| macOS arm64, send | | |
| macOS arm64, opt-out | | |
| macOS arm64, dead endpoint | | |
| Linux x64 | | |
| Windows (no app run possible) | | |
| Phone regression | | |
| Date alignment | | |
| QA exclusion | | |
| Bytes | | |
| Website | | |

## Decisions log

- Owner's privacy wording and legal review:
