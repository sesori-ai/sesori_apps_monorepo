# Step 4 — Hermes cleanup and held runtime target

## Outcome

- **Ship the localized cleanup fix; do not update the Hermes target.** The target
  remains `0.20.4`, with independent minimum `0.20.0` unchanged.
- Six API tests, five existing catalog-repository tests and the owning analyzer
  pass. No production classes were added or moved. Lifecycle ownership,
  database schema, wire contracts, authentication policy and generated files
  are unchanged.
- Candidate `0.21.2` native verification is **not accepted**. The attempted
  saved-session load failed, and parent review found isolation, launch and
  evidence-preservation departures from the agreed verification procedure.
  Neither successful setup calls nor the driver's completion flag waive them.

## Production change and source basis

`HermesCatalogRepository` already settles its disposable ACP process before
calling `HermesAcpApi.deletePersistedSession`. The API now accepts either a
successful CLI exit or the precise benign absence response: exit 1, stdout
`Session '<requested-id>' not found.`, and empty stderr. The absence remains
observable through a local debug diagnostic. Other nonzero results still throw,
now retaining both diagnostic streams rather than losing stdout-only errors.

This fixes an ordinary compatible-PATH flow, independently of adopting a new
recommended target. Tagged Hermes source skips persistence for empty ACP
sessions, while its CLI treats deletion of a missing session as exit 1:

- [Empty-session persistence](https://github.com/NousResearch/hermes-agent/blob/939e45c91d751fadd94dcd1b873ac3cb44846213/acp_adapter/session.py#L294-L300)
- [Missing-session response](https://github.com/NousResearch/hermes-agent/blob/939e45c91d751fadd94dcd1b873ac3cb44846213/hermes_cli/sessions_cmd.py#L46-L48)
- [Named-session deletion](https://github.com/NousResearch/hermes-agent/blob/939e45c91d751fadd94dcd1b873ac3cb44846213/hermes_cli/sessions_cmd.py#L529-L543)

No extra database lookup, version branch, retry, lock or cleanup registry was
added. The existing discovery/fallback policy remains unchanged.

## Accepted focused verification

Dart **3.13.3**, from the repository-pinned Flutter SDK:

- `test/hermes_acp_api_test.dart`: **6 cases** — successful deletion, exact
  benign absence, retained stdout/stderr diagnostics, and rejection of other
  exit codes, another session's absence response, or accompanying stderr errors.
- `test/hermes_catalog_repository_test.dart`: **5 cases** — mapping and existing
  settlement-before-delete, cleanup-failure and missing-ID behavior.
- `dart analyze --fatal-infos` in `bridge/sesori_plugin_hermes`: no issues.
- Both changed Dart files were formatted. After correcting the test fixture,
  its final formatting pass made no changes.

The initial API test file did not load because its fake implemented
`AcpProcessFactory`, which is a function typedef. It was replaced with a
throwing callback; only that failed suite was rerun. The already-passing five
repository cases were not repeated. **11 distinct passing cases**, not retries.

## Native observations — not accepted as an isolated pass

Two full native attempts ran before the stop instruction, using candidate
source at `939e45c91d751fadd94dcd1b873ac3cb44846213` (`v2026.9.11`, CLI `0.21.2`).
They used actual production `HermesAcpApi`, `HermesCatalogRepository`, host-backed
ACP/process adapters and a synthetic local provider, not fabricated ACP frames.

Retained driver results report CLI identity, model catalog discovery, exact
not-found cleanup, initialize/authentication, configured new/prompt, persistence
and fresh-process listing. The worker reported four ACP leases per attempt;
the retained second-attempt JSON records four disposal exits of `-15`.
These observations support investigation but do not establish
compliance with the required verification boundary.

Fresh-process load returned no model state or replay. The worker captured:

```text
resolve_provider_client: custom/main requested but no endpoint credentials found
RuntimeError: No LLM provider configured...
load_session: session ... not found
```

Source inspection corroborates the relevant distinction: `_restore` forwards
stored provider/base-URL metadata to `_make_agent`, but `_make_agent` resolves
credentials using the provider identifier without passing that base URL into
`resolve_runtime_provider`. The observed named custom-provider selection became
bare `custom`. This remains an investigation finding, not a verified regression
versus `0.20.4` or proof about other provider configurations. The non-faithful
launcher and lost original state limit attribution.

The retained second-attempt JSON has `success: true` because the driver completed
its sequence, while `loadReturnedModelState` and `loadReplayedHistory` are false.
It also reports nonempty post-discovery listing after reusing the prior attempt's
profile. That is not proof of a leaked discovery row: the named scratch deletion
reported absence. The global completion flag is **not** a gate result.

## Procedure and evidence limits

Parent inspection found these departures; no further native retry was approved:

- The wrapper dispatched directly to Python `acp_adapter.entry.main` for ACP,
  bypassing the normal `hermes acp` CLI dispatcher. Exact production launch was
  therefore not established.
- The host command executor used environment inheritance. The outer script
  exported selected values without clearing the inherited environment, and the
  wrapper extended inherited `PYTHONPATH`. A fully allowlisted environment was
  not established.
- The sandbox permitted reads outside user-home trees, broad process operations,
  writes to the sandbox subtree containing runtime/source inputs, and outbound
  access to `localhost:*`, not just the fixture endpoint. External network denial
  alone did not satisfy the agreed filesystem/environment/localhost boundary.
- The 240-second deadline began after setup/analysis and fixture creation. It
  was not a bound over the whole setup lifecycle; timeout cleanup was not
  fault-injected or proven. Normal exits do not establish that stronger claim.
- Before the stop arrived, the worker reset its disposable profile and recreated
  fixture run files. The original database, candidate logs, caches and original
  fixture request log are gone. The profile's `.env` and `config.yaml`, latest
  driver JSON, scripts, preserved report and captured tool output remain. Do not
  cite deleted paths as retained raw evidence or reconstruct them as originals.
  Successful production deletion of the configured persisted sessions was not
  demonstrated; removing profile files does not satisfy that gate.

No exposure of real credentials or external provider traffic was established;
conversely, the run cannot substantiate the promised absence of ambient inputs.
No user-owned session database was targeted by the disposable-profile reset.

## Cleanup and remaining work

A separate same-session **cleanup-only** follow-up verified the extra fixture's
current process identity and listener, sent SIGTERM, and confirmed both process
and listener absent. It was already reparented, so this was observed exit/absence,
not `wait(2)` reaping by that follow-up. No historical PID was signaled and no
candidate execution occurred after the stop. Cleanup does not repair the failed
or unaccepted verification evidence.

A future target update still needs faithful, correctly isolated native launch,
configured persistence/load and cleanup evidence under an explicitly reviewed
procedure. This PR makes no target, real-authentication, other-platform or client
UI coverage claim. The broader plan remains active with the Hermes pin blocked.

Local, non-public evidence is under `.dart_tool/runtime-refresh-validation/hermes/`:
`parent/` retains accepted test/analyzer logs, the source-freeze checkpoint,
`native-blocked-REPORT.md`, `native-blocked-probe-result.json` and the preserved
controller; `native/cleanup-followup/` retains the final ownership result.
