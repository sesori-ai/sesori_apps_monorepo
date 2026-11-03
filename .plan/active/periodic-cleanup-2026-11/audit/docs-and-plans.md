# Docs and plans cleanup audit (XC-DOC)

## Summary

Docs and plans are now the main source of stale guidance. Regression docs are healthy: the README indexes all 47 docs, and every referenced test file, route and flag exists. Neither the release history nor the top-level runbooks show drift.

The debt sits in three places.

1. **Plans stuck in `.plan/active/`.** 8 of the 11 active plans have finished their implementation but are stuck at the last "coverage passes, then retire" step. Together they hold about 13.5k lines. Some of their trackers contradict merged PRs.
2. **One plan left dormant code behind.** path-runtime-authority-split stopped after step 6. `runtimeUpdateSpec` and `PluginControlCapability.runtimeUpdate` are implemented in 8 descriptors, but production never calls them.
3. **Agent-facing structure maps that contradict the code.** These are worse than stale prose because agents follow them:
   - shared/sesori_shared/AGENTS.md tells agents to "Add OpenCode model" in shared.
   - The two architecture-review skills, client/AGENTS.md, and the module_core and module_auth docs cite classes that do not exist (`AuthRedirectService`, `SseEventService`, `AppUpdater`) and the wrong `foundation/platform` path.

ROADMAP and VISION still list shipped stages as "planned", and docs/plans and docs/reports hold two orphaned one-off documents.

Estimated effect:
- about 13.5k plan lines moved out of active;
- about 450 doc lines deleted;
- about 150–250 code and test lines removed if the dormant runtime-update seam goes;
- about 150 lines of agent docs corrected.

## Findings

### XC-DOC-1 Retire eight finished or stalled plans in one move, with explicit accepted-gap notes
- Category: leftover
- Evidence:
  - Per-plan evidence is in the table below.
  - These plans have every implementation PR merged, and only the final docs, coverage or retire step is open:
    - opencode-v2: #1795 merged 2026-09-26, but the tracker still says "#1795 open".
    - step-timers: #1772–#1787 merged 2026-09-26.
    - desktop-sign-in: steps 1–7 merged by 2026-09-26.
    - desktop-app: steps 1–20 done; Gate C retired by the user 2026-09-26.
    - quota-auto-continuation: all 7 PRs merged 2026-09-24.
    - mcp-management: step 36 merged as #2012, but TRACKER.md:68 still says "Prepared".
  - Two more plans stopped at a step that will never run:
    - session-refresh-reconnects: live observation. Its fixes landed via periodic-cleanup #1299/#1303.
    - user-analytics: owner Looker and reconciliation actions, stalled since #784 on 2026-08-08.
  - The cause is structural. The plan-maker skill retires a plan to `.plan/completed/` "only after that coverage passes", so any plan whose last step is device, macOS or owner QA never leaves `active/`. The precedent for doing it anyway exists: desktop-ux, desktop-ui-polish and visual-hierarchy all retired "accepting unexecuted live/device checks" (docs/ROADMAP.md:45-52).
  - Links that must be repointed when these plans move (verified with `rg '\.plan/active/'`):
    - client/desktop/AGENTS.md:7
    - client/module_desktop_core/AGENTS.md:8
    - docs/regression/desktop-bridge-supervision.md:407
    - docs/regression/account-and-onboarding.md:206
    - docs/regression/quota-auto-continuation.md:14,133
    - docs/HARNESS_CAPABILITIES.md:128,130,838
    - tool/mcp-contracts/README.md:56
    - docs/regression/session-turns.md:1137
    - docs/cleanup-audit-2026-09-04.md:90
    - docs/ROADMAP.md and docs/VISION.md, which are covered by XC-DOC-5
- Proposal:
  - Make one docs-only PR that uses `git mv` to move the 8 directories to `.plan/completed/`.
  - Append a dated "Retired with accepted gaps" note to each TRACKER that names the unexecuted check: macOS QA, L4, Apple sign-in on macOS, or the owner warehouse actions.
  - Correct the stale states (#1795 open, step 36 Prepared) in the same edit.
  - Repoint the links listed above.
  - client/desktop/AGENTS.md:7 and client/module_desktop_core/AGENTS.md:8 say "built out step by step — see .plan/active/desktop-app". Drop that clause entirely; the structure is complete.
  - Optionally add one sentence to plan-maker: a plan whose remaining coverage is user-owned or deferred may retire with an explicit accepted-gaps note. This stops future stalls.
- Size:
  - about 13.5k lines moved, a rename only (desktop-app 2796, mcp-management 3025, user-analytics 2739, quota 1930, desktop-sign-in 896, step-timers 884, opencode-v2 620, session-refresh-reconnects 595);
  - about 40 lines of retirement notes and link fixes across about 12 files.
- Risk: low. Docs only. No wire, database or user-visible impact.
- Confidence: verified. PR states come from `gh pr view`, and the tracker contents were read.
- Decision needed, per plan:
  - Do you accept the open gaps for quota-auto-continuation (macOS QA), mcp-management (step 37 L4/external checks; native recording already deferred by the user), desktop-sign-in (full Apple sign-in on a macOS build) and user-analytics (Looker report and 3-day reconciliation)? The alternative is folding user-analytics's remaining owner actions into desktop-analytics step 10.
  - The other four plans need no decision.
  - Retiring desktop-app also fulfils the reopening condition for the deferred "Desktop attention" item. See the deferred re-check below.

### XC-DOC-2 path-runtime-authority-split stopped halfway and left a dormant runtime-update seam in 8 plugins
- Category: leftover
- Evidence:
  - The plan's steps 1–6 merged (#1462/#1463/#1466/#1472/#1473/#1474). The tracker still says step 6 is "In progress". Step 7 (wire and bridge execution of global runtime updates), step 8 (client presentation) and step 9 (retire) were never started. Last activity was 2026-09-14.
  - The seam:
    - `PluginRuntimeUpdateSpec` is defined at bridge/sesori_plugin_interface/lib/src/lifecycle/bridge_plugin_descriptor.dart:24, with the base `runtimeUpdateSpec(...) => null` at :112.
    - `PluginControlCapability.runtimeUpdate` is defined at plugin_control_capability.dart:21.
    - Eight descriptors override `runtimeUpdateSpec` and declare `runtimeUpdate`: claude, opencode, codex, cursor, hermes, pi, omp and grok.
  - `rg '\.runtimeUpdateSpec\('` finds no production caller.
  - bridge/app/lib/src/services/plugin_lifecycle_service.dart:1306-1308 maps the spec to null with the comment "Descriptor-owned updater metadata stays internal until command transport and execution support are available".
  - About 12 test files exercise the seam.
  - docs/HARNESS_CAPABILITIES.md:334 and :355-358 document it as "not yet executable".
- Proposal (two options):
  - (a) Remove the spec type, the capability value, the 8 overrides, their tests and the HARNESS_CAPABILITIES rows, then retire the plan as abandoned at step 6.
  - (b) Re-plan steps 7–9 as a fresh plan, and retire this plan.
  - Either way, the plan should leave `active/`.
- Size: option (a) removes about 150–250 lines across the interface, 8 descriptor files, about 12 tests and docs.
- Risk: low to medium for (a).
  - The capability enum may be serialized. Check whether `PluginControlCapability.runtimeUpdate` ever crossed the wire to the client in a public release before deleting the enum value.
  - The plugin interface itself has no external consumers.
- Confidence: verified that there are no production call sites. Wire exposure of the enum value needs a check.
- Decision needed: should global runtime updates from the phone or desktop still happen (finish later) or not (remove now)? Cross-slice: the plugin-interface auditor may report the same dead code; deduplicate at consolidation.

### XC-DOC-3 shared/sesori_shared/AGENTS.md misdescribes the package and directs backend models into shared
- Category: leftover (stale guidance that contradicts the North Star)
- Evidence: the file was last edited 2026-08-22 and is 72 lines.
  - It claims "Barrel export (24 exports)"; there are actually 122.
  - It lists `models/opencode/` "OpenCode models — Session, Project, Message, AgentInfo, Provider". That directory does not exist; the real models are in `models/sesori/`.
  - It cites `LogoutUrlResponse`, which does not exist.
  - It says "RelayMessage sealed class — 11 variants"; there are 19.
  - It omits the auth, concurrency, constants, converters, extensions, notifications, reporting, search, transcript and voice directories, and protocol/control_message.dart.
  - Its WHERE TO LOOK row "Add OpenCode model | src/models/opencode/" tells agents to put backend-specific models in shared, against AGENTS.md "Backend-specific behavior stays inside its plugin package".
- Proposal:
  - Rewrite STRUCTURE as a short directory list without counts, since counts go stale.
  - Delete the OpenCode row, `LogoutUrlResponse` and the variant count.
  - Replace the OpenCode row with "backend-neutral Sesori models: src/models/sesori/; backend models belong in the plugin".
- Size: about 40 lines changed in 1 file.
- Risk: low. Docs only.
- Confidence: verified.
- Decision needed: none.

### XC-DOC-4 Architecture-review skills and client AGENTS/READMEs cite nonexistent classes and the wrong module_core layout
- Category: leftover (stale agent guidance)
- Evidence:
  - .agents/skills/architecture-plan-review/SKILL.md (:405-430, :496-512, :579) and architecture-implementation-review/SKILL.md (:463-488, :554-570, :637) share an almost identical module_core B-C4 map. It is wrong in these places:
    - It puts UrlLauncher, DeepLinkSource, LifecycleSource, RouteSource and NotificationCanceller in `lib/src/foundation/platform/`; they are in `client/module_core/lib/src/platform/`.
    - It puts RelayClient and ConnectionService in `lib/src/foundation/transport/`; they are in `lib/src/capabilities/{relay,server_connection}`.
    - It lists `foundation/{logging,concurrency,extensions}`; logging is at `lib/src/logging`, and the other two do not exist.
    - It gives `api/voice_api.dart`; the file is `capabilities/voice/voice_api.dart`.
    - It gives `services/sse_event_service.dart`, which does not exist.
  - The two skills (1050 and 1170 lines) share about 300 near-identical lines.
  - client/AGENTS.md:164-171:
    - gives the same wrong platform location;
    - uses `SseEventService` and `AuthRedirectService` as Layer 3 examples, and neither exists anywhere in git history;
    - names `AppUpdater` as a desktop Layer 0 capability, which does not exist (the real interfaces include sparkle_update_engine, system_tray, window_host and launch_at_login).
  - `AuthRedirectService` also appears in:
    - client/module_core/AGENTS.md:27 (routing really holds app_routes.dart, analytics_route_listener, computer_switch_dispatcher and notification_open_dispatcher);
    - client/module_core/README.md:45;
    - client/module_auth/AGENTS.md:19.
  - `AppUpdater` also appears at client/module_desktop_core/AGENTS.md:13.
  - client/module_core/AGENTS.md "Package Structure" is otherwise accurate.
- Proposal:
  - In both skills, replace the duplicated module_core map with a pointer to client/module_core/AGENTS.md "Package Structure", the single source. Keep the rules and checks.
  - Fix the class names and the path in the 5 AGENTS/README files.
  - Keep the hypothetical code-excerpt teaching examples, which are not presented as real files.
- Size: about 60–90 lines removed from the skills; about 15 lines changed across 5 docs.
- Risk: low. This changes reviewer instructions only, and reviewers become more accurate. The bridge, OpenCode and module_auth Location paths in the skills were verified and stay.
- Confidence: verified.
- Decision needed: none.

### XC-DOC-5 ROADMAP and VISION describe shipped stages as planned and link to retired or moved plans
- Category: leftover
- Evidence:
  - docs/ROADMAP.md (203 lines, last edited 2026-09-25):
    - Stage A is "in progress", yet macOS desktop (v1.9.1) and stable Linux (#2042) are public.
    - Stage B2 is "planned next" with Detail `.plan/active/setup-aware-plugin-lifecycle/PLAN.md` (:105); that plan is in `.plan/completed/`.
    - Stage B3 "phone-driven install and login — later, not yet planned" shipped as phone-harness-install, claude-code-login and codex-mobile-login.
    - Stage C "Multi-bridge addressing" shipped as multi-computer (docs/regression/multi-computer.md).
    - "Notes on ordering" (:189-201) still mentions session PR-monitoring, which was removed (pr-tracking-removal), and desktop-app as active (:6, :39, :197).
  - docs/VISION.md:179-187 "Related docs" lists the same stale setup-aware path and desktop-app as active.
- Proposal:
  - Mark A (macOS/Linux), B2, B3 and C as complete in one line each, with links to their completed plans.
  - Collapse "Notes on ordering" to the stages still ahead (A's Windows distribution, then D, E, F, G).
  - Fix the VISION related-docs list.
- Size: about 60–80 lines removed or condensed; 2 files.
- Risk: low.
- Confidence: verified for B2/B3/C and setup-aware. The exact Stage A wording depends on desktop-distribution's Windows status, which is blocked on signing.
- Decision needed: none, unless the user wants ROADMAP retired in favour of VISION.

### XC-DOC-6 docs/plans/auth-reconnect-ux-plan.md is an orphaned plan outside .plan
- Category: leftover
- Evidence:
  - It is the only plan in docs/plans (192 lines, last edited 2026-06-15), and its status still says "in progress".
  - Tier 1 shipped (#262, #264, #265, #266). PRs 4–7 never started, and PR 7 needs a product call.
  - Its paths are stale:
    - `mobile/...` is now `client/`;
    - `bridge/app/lib/src/bridge/orchestrator.dart` is now `bridge/app/lib/src/orchestrator.dart`;
    - `bridge/app/lib/src/bridge/sse/sse_manager.dart` and `connection_overlay.dart` are gone.
  - No doc links to it except the README index.
- Proposal: delete the file and the docs/plans directory. If the user still wants the unstarted reconnect-UX ideas, keep them as a short `.plan/drafts/auth-reconnect-ux/DRAFT.md` of about 20 lines.
- Size: about 192 lines removed; 1–2 files.
- Risk: low.
- Confidence: verified.
- Decision needed: should the unstarted reconnect-UX ideas (PRs 4–7) be kept as a draft or dropped?

### XC-DOC-7 docs/reports/chat-payload-before-after is a one-off review artifact for a merged PR
- Category: leftover
- Evidence:
  - The directory holds README.md (27 lines) and index.html (169 lines, about 40 KB), a review report for #1221. The review is dated 2026-09-10, and the PR merged 2026-09-11.
  - Its own README says "Later source changes can supersede this report".
  - Only `.plan/completed/periodic-cleanup` references it.
- Proposal: delete the directory. The completed plan's link becomes historical; optionally point it at #1221.
- Size: about 196 lines removed (40 KB); 2 files.
- Risk: none.
- Confidence: verified.
- Decision needed: none.

### XC-DOC-8 docs/ARCHITECTURE.md omits three packages the products depend on
- Category: leftover
- Evidence:
  - The repository structure (:5-37) and the dependency graph (:41-125) omit three packages:
    - client/module_app_ui (`sesori_app_ui`), the shared UI that both app and desktop depend on;
    - client/module_persistence (`sesori_persistence`);
    - client/design_catalog.
  - The graph lacks app/desktop → sesori_app_ui and module_core → sesori_persistence.
  - Last edited 2026-09-08.
- Proposal: add the 3 packages and 3 edges.
- Size: about 15 lines changed; 1 file.
- Risk: low.
- Confidence: verified.
- Decision needed: none.

### XC-DOC-9 bridge/app/README.md and client/app/AGENTS.md show directory trees that no longer exist
- Category: leftover
- Evidence:
  - bridge/app/README.md:292-307 "Project Structure" shows a `lib/src/bridge/` subtree containing relay_client.dart, orchestrator.dart, key_exchange.dart, routing/, sse/ and debug_server.dart. That directory does not exist. The real locations are:
    - lib/src/orchestrator.dart
    - lib/src/debug_server.dart
    - lib/src/foundation/key_exchange.dart
    - lib/src/routing
    - lib/src/sse
  - The same tree misses control/, listeners/, models/, persistence/ and runtime/.
  - client/app/AGENTS.md:35 lists `lib/core/extensions/`, which does not exist. The real `lib/core` holds di, external_link.dart, platform, routing and widgets.
- Proposal: replace the README tree with the top-level `lib/src` directories (or a pointer to bridge/app/AGENTS.md), and fix the client/app line.
- Size: about 20 lines changed; 2 files.
- Risk: low.
- Confidence: verified.
- Decision needed: none.

### XC-DOC-10 Delete the superseded phone-plugin-runtime-installation draft
- Category: leftover
- Evidence:
  - `.plan/drafts/phone-plugin-runtime-installation/DRAFT.md` (17 lines, 2026-07-22) is fully delivered by `.plan/completed/phone-harness-install` and docs/regression/plugin-runtime-installation.md.
  - Phone login shipped later (claude-code-login, codex-mobile-login).
- Proposal: delete the draft directory.
- Size: 17 lines removed; 1 file.
- Risk: none.
- Confidence: verified.
- Decision needed: none.

### XC-DOC-11 docs/cursor-acp-followups/README.md names deleted files and symbols
- Category: leftover
- Evidence:
  - Item D1 is still valid:
    - Cursor `create_plan` passes `resolutionBuilder: null` (bridge/sesori_plugin_cursor/lib/src/cursor_approval_registry.dart:181-190).
    - ACP `_rejectAcpQuestion` falls back to an error "user rejected" (bridge/sesori_plugin_acp/lib/src/acp_approval_registry.dart:73-79).
  - Item E is partly stale:
    - `acp_content.dart` was deleted on 2026-08-01 by #661 and replaced by repositories/mappers/acp_content_mapper.dart.
    - `acpToolName` no longer exists.
    - Typed DTOs now exist (acp_content_block_dto.dart, acp_tool_content_dto.dart).
    - Raw-Map handling still exists in acp_event_mapper.dart (19 lines) and acp_session_loader.dart (9 lines).
- Proposal: rewrite item E against the current files. Alternatively, move D1 and E to two GitHub issues and delete the 32-line doc, which is the only one of its kind in docs/.
- Size: 32 lines changed or removed; 1 file.
- Risk: none.
- Confidence: verified.
- Decision needed: keep it as a doc, or convert it to issues?

### XC-DOC-12 docs/regression/desktop-distribution.md carries plan evidence instead of behavior
- Category: leftover (regression-doc hygiene)
- Evidence:
  - The file is 809 lines and contains 10 GitHub run IDs, 11 commit SHAs and dated history:
    - lines 261-262, 534-541, 557, 578-579, 631-635, 676, 694-701;
    - the "Current evidence boundary" section at 705-742.
  - It links into `.plan/active/desktop-distribution/steps/step-06/07/09.md`.
  - AGENTS.md says regression docs track supported behavior and coverage, not history.
- Proposal: when desktop-distribution next touches the doc, or at its retirement, move the run, SHA and date evidence into the plan's evidence files and keep the behavior and coverage rows.
- Size: about 80–150 lines removed from the regression doc.
- Risk: low.
- Confidence: likely. The exact trim depends on which rows the distribution plan still uses as live gates.
- Decision needed: none. Do it at plan retirement; it is not urgent.

### XC-DOC-13 Small stale states and broken links in plans that stay active, and in test comments
- Category: leftover
- Evidence:
  - desktop-distribution:
    - PLAN links `../desktop-auto-update/PLAN.md`, which is now in `.plan/completed/`.
    - Step 9 (Linux) is still "in-progress", although stable Linux shipped (#2042, 2026-10-25).
  - session-refresh-reconnects TRACKER links `../periodic-cleanup/PLAN.md` and `../periodic-cleanup/evidence/README.md`, which moved to completed. This is moot if XC-DOC-1 retires the plan.
  - bridge/sesori_plugin_codex/test/codex_sub_agent_item_parser_test.dart:9 and codex_sub_agent_metadata_dto_test.dart:7 cite `.plan/active/claude-inline-subtasks/followups/codex-probe.md`; the file is at `.plan/completed/claude-inline-subtasks/followups/codex-probe.md`.
  - path-runtime-authority-split step 6 "In progress" is covered by XC-DOC-2.
- Proposal: fix the paths and the step-9 status. Fold these edits into the XC-DOC-1 PR.
- Size: about 6 lines changed; 4 files.
- Risk: none.
- Confidence: verified.
- Decision needed: none.

### XC-DOC-14 (optional, low value) Condense the MCP narrative in HARNESS_CAPABILITIES and file away the previous audit record
- Category: simplification
- Evidence:
  - docs/HARNESS_CAPABILITIES.md:661-967 ("MCP management native evidence", about 300 lines) is implementation-narrative prose. It overlaps docs/regression/mcp-management.md (890 lines) and links into `.plan/active/mcp-management/evidence/`.
  - The rest of the file was spot-checked and is accurate (see Checked and kept).
  - docs/cleanup-audit-2026-09-04.md (444 lines) is the record of the previous audit. Its plan, periodic-cleanup, is completed.
- Proposal:
  - Reduce the MCP section to a per-harness gap table of about 60 lines and point to the regression doc.
  - When this audit's record lands, move the 2026-09-04 record into `.plan/completed/periodic-cleanup/` so docs/ holds at most one current audit record.
- Size: about 240 lines removed from HARNESS_CAPABILITIES; 1 file moved.
- Risk: low. The harness-gap facts must survive the condensation.
- Confidence: likely.
- Decision needed: none. Skip it if review budget is tight.

## Plan and draft classification

| Name | Status | Evidence | Proposed action |
|---|---|---|---|
| active/desktop-analytics | In progress | Steps 1, 6, 7.b and 9 merged (#2288, #2289, #2295, #2297, #2299). Step 8 waits on the website; step 10 not started. Pipeline drill 2026-11-02. Last activity 2026-11-01. | Keep. |
| active/desktop-app | Implementation done; closeout stalled | Steps 1–20 done; Gate C retired by the user 2026-09-26. Steps 21–22 (regression reconciliation, coverage, handoff) pending. Last own PR #1274 on 2026-09-03. | Retire with accepted gaps (XC-DOC-1). Fix the 2 AGENTS headers and the regression link. |
| active/desktop-distribution | In progress / blocked | Windows steps 7, 8 and 10 blocked on signing. Step 9 Linux shipped (#2042) but still marked in progress. Steps 11–12 pending. Last commit 2026-10-31. | Keep. Fix step 9 status and the broken desktop-auto-update link (XC-DOC-13). |
| active/desktop-sign-in | Stalled at retire step | Steps 1–7 merged by 2026-09-26. Step 8 (record matrix, retire) never ran. Full Apple sign-in on a macOS build pending the user. Feature is public. | Retire with accepted gap, after user confirms (XC-DOC-1). |
| active/mcp-management | Stalled at retire step | Step 36 merged as #2012 but the tracker says "Prepared". Step 37 (L4 and external checks) not started. Last own commit 2026-10-16. Native recording deferred by the user. | Retire with accepted gap, after user confirms. Repoint 2 links (XC-DOC-1). |
| active/opencode-v2 | Finished except retire | Steps 1–9 merged (#1795 on 2026-09-26; tracker still says open). Step 10 coverage/retire never ran. v2 is public. | Retire (XC-DOC-1). |
| active/path-runtime-authority-split | Stalled since 2026-09-14 | Steps 1–6 merged (#1462–#1474). Steps 7–9 never started. Dormant `runtimeUpdateSpec` seam in 8 plugins. | Decision: finish in a new plan, or remove the seam. Either way, retire (XC-DOC-2). |
| active/quota-auto-continuation | Implementation done; QA partial | All 7 PRs merged 2026-09-24. Step 7 macOS QA blocked by the user's decision on 2026-09-24. | Retire with accepted gap, after user confirms (XC-DOC-1). |
| active/session-refresh-reconnects | Stalled since 2026-08-04 | Steps 1–2 merged (#725, #734). Step 3 live observation never happened. Fixes came via #1299/#1303. Reconnect logging was extended in f8f66a320f. | Retire (XC-DOC-1). |
| active/step-timers | Phase 1 finished except docs/retire | Steps 1–5 merged 2026-09-26. Regression docs already cover timers. Follow-up #1919 landed. Phase 2 is intent only. | Retire phase 1 (XC-DOC-1). |
| active/user-analytics | Stalled since 2026-08-08 | Pipeline live; only owner actions remain: Looker report, clean sweep, 3-day reconciliation, then flip `DEPLOYMENT_RECORD_STATUS`. | Owner confirms the actions, or folds them into desktop-analytics step 10; then retire (XC-DOC-1). |
| drafts/phone-plugin-runtime-installation | Superseded | Delivered by completed/phone-harness-install and plugin-runtime-installation.md. Phone login shipped too. | Delete (XC-DOC-10). |
| drafts/prompt-attachment-uploads | Dormant, still valid | Composer still base64-inlines images with a 50 MB cap (client/module_core/lib/src/foundation/models/composer/composer_attachment.dart:7). Some facts stale (harness image list; "Claude ... active plugin plan"). | Keep; refresh facts when activated. |

## Re-check of deferred items in this slice

- **Desktop attention** (CONSOLIDATION.md:66): the reopening condition is "after the desktop-app manual-testing gate and retirement". The gate was retired on 2026-09-26; plan retirement is the remaining half. Once XC-DOC-1 retires desktop-app, the condition is met and the item becomes eligible for its own architecture-scoped plan. The consolidator or the desktop auditor should decide on scope; this slice does not re-propose the code change.
- Shared Flutter adapters, Listener pairs and Compatibility floor: no docs or plans aspect. Outside this slice.
- docs/cleanup-audit-2026-09-04.md retained no docs-specific items.

## Checked and kept

- docs/regression/*: README indexes all 47 docs with no dangling entries. All referenced test files, routes and CLI flags exist.
  - Unmatched identifiers are external or native names: warehouse tables, GenericBrowser/webbrowser, invoke_subagent, web_fetch, permissions.deny, auto_edit, sesori_probe, kIOMessage* (Swift), and the example path `/root/architecture_review_1271`.
  - `background_tasks_changed` is explained as intentionally unused.
- Tombstone scan:
  - session-archiving-and-deletion.md:106 retired `deleteBranch` is a live wire-compatibility invariant; keep it.
  - plugin-setup-and-lifecycle.md:33 ("removed `session.compaction.ended` `recent` field") is upstream pin context, not a Sesori tombstone.
  - transcript-turn-navigation.md:514 "Two-finger touch scrolling no longer scrolls" describes current behavior.
- docs/HARNESS_CAPABILITIES.md is accurate where checked:
  - Managed-install rows match `PluginControlCapability.install` (claude, hermes and grok have none).
  - Updater rows match the 8 overrides.
  - Login-initiation rows match the authentication capability (claude, codex, antigravity).
  - Version pins match the manifests: OpenCode 1.14.0/2.1.4, OMP 18.12.6, Codex 0.164.0, Pi 1.4.0, Copilot 1.0.103, Cursor 2026.10.22, DeepSeek 0.2.1, Antigravity 1.4.3.
- Other top-level docs (GETTING_STARTED, HOW_IT_WORKS, SECURITY, SETUP_HEADLESS_VM, STORE_METADATA, CONTRIBUTING, ANTIGRAVITY) and docs/desktop/*.md runbooks: every documented CLI flag exists. Namespaced plugin flags such as `--antigravity-bin` are valid.
- `.claude/skills/*/SKILL.md`: all 10 shims resolve to `.agents/skills/*`.
- No references remain to removed skills or files (macos-desktop-qa, .opencode skills, .mcp.json; consolidated in 50b00d69f0). Remaining `.mcp.json` mentions are harness-native config (tool/mcp-contracts/probe.mjs, plan evidence).
- Root AGENTS.md already uses the renamed `plan-maker`. `sesori-local-testing` is a user-global skill, so its references are fine.
- update-dependencies skill: its inventory covers all 29 pubspecs, and the untracked `shared/no_slop_linter/pubspec.lock` reference is intentional. github-runner-desktop-qa, harnesses.md and add-analytics paths all exist.
- Architecture skills: the bridge (B-B5), OpenCode (B-B4) and module_auth (B-C3) Location paths exist. Hypothetical code excerpts are teaching examples and stay.
- drafts/prompt-attachment-uploads: kept, see table.
- `.plan/active/desktop-analytics` and `desktop-distribution`: genuinely in progress; not proposed for retirement.
