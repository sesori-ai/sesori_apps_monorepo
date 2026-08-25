# Sesori Regression Testing

This directory is the durable source of truth for agent-run regression testing.
Each file describes one product capability, its required behavior, and the
coverage each level adds. The agent varies prompts, order, fixtures, and tools;
fixed outcomes keep pass/fail stable without prescribing one brittle script.

## Regression Levels

| Level | Name | Purpose |
|---|---|---|
| L1 | Smoke | Detect catastrophic breakage through a few critical product heartbeats. |
| L2 | Routine | Exercise important normal behavior through the shortest trustworthy boundary. |
| L3 | Release | Establish release confidence across critical user journeys and required production plugins. |
| L4 | Extended | Add recovery, concurrency, multi-client, adverse-state, and alternate-platform variation. |
| L5 | Full | Run the complete documented matrix, including rare, destructive, packaged, compatibility, and external-system checks. |

Levels are cumulative: Level 3 runs every applicable L1, L2, and L3 entry. An
entry is inapplicable only when none of its checks concern behavior present in
the build, including capability omission or compatibility behavior; missing
infrastructure makes it `Blocked`. A higher-level check through an equal or
stronger boundary can satisfy the same lower-level invariant once. A feature
can enter at any level. "Full" means the documented catalog, not every
theoretical input. Tables use two empty states:

- **Not included:** this feature has no coverage at this level.
- **No additional coverage:** lower-level coverage still runs, but this level
  adds nothing.

## How To Run A Level

1. Collect every feature entry from L1 through the requested level; empty states
   add no work and never remove lower-level coverage.
2. Use the shortest boundary proving the whole requirement. Do not launch a
   simulator for a bridge-only contract or replace client evidence with a route.
3. Follow plugin and platform scope; one passing target proves only that target.
4. Vary actions using the exploration guidance, especially from the prior run.
5. Keep privacy-safe evidence, restore mutated state, and perform named cleanup.

When a requested level is too broad for the available environment, run the
available subset and report partial coverage. Never silently convert an omitted
plugin, platform, external service, or required boundary into a pass.

## Proof Boundaries

Use the lowest boundary that observes the complete invariant:

| Boundary | Appropriate use |
|---|---|
| Automated | Deterministic model, persistence, mapping, widget, ordering, or failure behavior already proved completely by an owning test suite. |
| Headless bridge | Bridge routes, debug events, settings, persistence, local Git behavior, lifecycle, restart, or routing where no product client behavior is involved. |
| Live plugin | A real coding backend must create, stream, approve, replay, or otherwise interpret the behavior, but no client surface is part of the claim. |
| Relay integration | Encryption, connection incarnation, delivery, or multiple logical clients is in scope, but a full product UI is not required. |
| Client end to end | Rendering, navigation, app lifecycle, device APIs, or the client-to-relay-to-bridge-to-plugin journey is part of the claim. |
| Packaged or external | Installers, signed artifacts, stores, push providers, GitHub, analytics, or another production service is part of the claim. |

An entry can name more than one boundary when its added coverage has independent
claims. Qualifiers such as fake services, fixtures, multiple clients, or a named
platform refine a boundary; they do not create another boundary.

End-to-end means traversing the complete authoritative boundary, not always a
phone: a bridge policy can end at the live plugin, while rendering needs the
client. The debug server can control and inspect bridge state but cannot prove
relay encryption or client presentation.

## JSON Serialization

Every package using `json_serializable` configures `include_if_null: false` in
its `build.yaml`. Generated payloads omit null-valued keys by default, while
decoders continue accepting omitted nullable fields. Feature regressions that
exercise JSON boundaries should preserve both sides of this invariant.

## Plugin Coverage

Backend-neutral implementation can still require every plugin when each
translates behavior. `Harness` and `plugin` mean the same thing. Entries use
these scopes, optionally narrowed to a declared capability:

- **None:** no plugin participates in the invariant.
- **Representative:** the bridge owns the behavior after a normalized plugin
  boundary, so one suitable plugin or a faithful fake proves it.
- **Every supporting production plugin:** each registered plugin that declares
  or exposes the capability must pass. Unsupported behavior is not a failure.

`Every registered production plugin` is broader and applies only when even
plugins without a specific capability must be represented, such as a registry or
setup listing. Use current registered plugins and declared capabilities from
production code, not a hard-coded historical list. Active plans and trackers are
useful discovery material but can describe unfinished or superseded behavior.

## Platform Coverage

`Release-target client platform` means one supported mobile platform selected
for the release under test; `alternate client platforms` means the remaining
supported mobile platforms. `Release-target bridge host` similarly means one
supported bridge OS and architecture selected for the release; alternate host
coverage expands that matrix. An entry with no platform-specific claim need not
invent one, but a missing required platform is `Blocked` or `Partial`.

## Results And Evidence

Report `Pass`, `Partial`, `Fail`, `Blocked`, or `Not run`, plus the level,
boundary, plugins, platforms, accounts, builds, versions, chosen variations,
privacy-safe evidence, failure's first divergent boundary, linked defects, and
cleanup or retained diagnostic residue.

A feature is fully passed only when every requirement accumulated through the
requested level passed across its complete declared matrix. Otherwise report
`Partial` when executed scope passed but its matrix was incomplete, `Blocked`
when required execution could not proceed, or `Fail` when behavior diverged.

Raw prompts, transcripts, source paths, tool output, image bytes, tokens,
account identifiers, and unredacted logs or screenshots stay outside the
repository. Store only privacy-safe summaries and references. Never weaken
encryption, authentication, or a plugin boundary to make a regression easier to
run.

## Feature Maintenance

The code and released product behavior are authoritative. When a material
feature or fix changes expected behavior, boundaries, capabilities, plugins,
platforms, or known limitations, update the relevant feature file in the same
change, or reconcile it in the penultimate documentation step of durable planned
work. Add a file only for a distinct capability natural to run independently.

Keep feature documents compact: state the capability and required behavior once;
in the level table describe only coverage added at that level, without repeating
lower-level requirements or prescribing exact tap sequences; preserve fixed
acceptance criteria while allowing exploratory execution; link current code,
meaningful automated tests, and historical plans as maintenance sources rather
than as substitutes for the contract; and record accepted limitations honestly,
never describing unshipped behavior as passing coverage.

Track supported behavior, material risks, and concrete failure signals worth
testing. When behavior, a route, a field, a migration, or a flag is removed,
delete stale references instead of adding a permanent assertion that it remains
absent. Document absence only when reintroducing the artifact would itself break
an active capability or security invariant.

For durable planned work, regression documentation is completed before the plan
is retired. The retirement step runs the level and matrix recorded in `PLAN.md`
through each feature's authoritative end-to-end boundary. A reduction requires
explicit user acceptance recorded in `PLAN.md`; otherwise partial, blocked,
failed, or unexecuted required coverage keeps the plan active.

## Feature Index

- [Account and onboarding](account-and-onboarding.md)
- [Analytics](analytics.md)
- [Attachments and images](attachments-and-images.md)
- [Bridge connectivity](bridge-connectivity.md)
- [Bridge installation and updates](bridge-installation-and-updates.md)
- [Design catalog](design-catalog.md)
- [Device Canvas ownership](device-canvas-ownership.md)
- [Diffs and source control](diffs-and-source-control.md)
- [Navigation transitions](navigation-transitions.md)
- [Notifications](notifications.md)
- [Permission auto-approval](permission-auto-approval.md)
- [Plugin runtime installation](plugin-runtime-installation.md)
- [Plugin setup and lifecycle](plugin-setup-and-lifecycle.md)
- [Popup alerts](popup-alerts.md)
- [Projects and sessions](projects-and-sessions.md)
- [Pull request monitoring](pull-request-monitoring.md)
- [Questions and permissions](questions-and-permissions.md)
- [Session archiving and deletion](session-archiving-and-deletion.md)
- [Session creation and options](session-creation-and-options.md)
- [Session history and recovery](session-history-and-recovery.md)
- [Session turns](session-turns.md)
- [Tools and file changes](tools-and-file-changes.md)
- [Voice input](voice-input.md)
