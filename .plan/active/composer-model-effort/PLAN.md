# Composer model and effort: medallion chip and orbits picker

## Status and scope

- Design agreed with the owner over 17 review rounds; the decisions below
  (D1–D10) are the complete record. Round 15 settled the picker; round 16
  settled how many rings show and which harnesses get them; round 17 settled
  the dark look, the OFF level and the full model list (D10).
- Phase 1 is detailed below. Later phases are intent only; each becomes its
  own plan when it starts.
- Phase 1 ships on the touch composer layout (`AgentModelButtons.compact ==
  false`, which both callers derive from `ComposerPresentation.pointer`):
  phone and touch iPad. The pointer layout keeps today's pills.

## Outcome

On a touch composer whose harness catalog is "orbit-shaped", the model pill,
the variant pill and the fast-mode button become one medallion chip. Tapping
it opens the orbits picker: one ring per model, effort as the angle along the
ring, fast mode in the corner. One press, slide and release (or one tap)
picks model and effort together. Every other catalog keeps today's pills.

## Decisions

- **D1 Orbit-shaped catalog (round 16, Q2 A).** Orbits appear for any harness
  whose catalog has exactly one provider with available models, every reported
  level (ignoring `none`) is on the shared ladder `off, minimal, low, medium,
  high, xhigh, max, ultra`, at least one model reports a level, and a model is
  selected. Decided from the data, never from the harness name or a plugin
  flag. No wire change. Today this matches Claude Code and Codex, and Pi and
  Oh My Pi with one provider in use (D10).
- **D2 Rings (round 16, Q1 A with the owner's note).** "Do latest 4 from each
  category: Latest Luna, Latest Terra, Latest Sol, Latest Astra." Group the
  available models by `family ?? id` in order of first appearance in the
  catalog, take each family's representative through
  `DefaultModelSelector.pickFromFamily` (the same rule the model picker uses,
  so rings and picker agree), and keep the first four. If the current model
  is not among them, it is appended when fewer than four rings exist and
  otherwise replaces the fourth. Rings keep catalog order, first
  outermost.
- **D3 "All N models".** Shown when the catalog has more available models than
  rings. It closes the orbits and opens today's `ModelPicker` popover from the
  chip ("the all 8 models I guess opens the regular picker like the other
  harnesses"), listing every model (D10).
- **D4 Codex reports families.**
  - A new public `CatalogStrengthOrder.openAiFamily(String id)` in the plugin
    interface reuses the existing OpenAI id parse (lowercasing, namespace and
    `[…]` stripping, the `gpt-<version>-<suffix>` match). It returns the
    suffix in display case (`Sol`, `Astra`, `Codex Mini`), or null for a bare
    id (`gpt-5.5`) or an id it cannot parse (`gpt-default`). A null family
    keeps the model its own family, with no subtitle.
  - `CodexModelRepository` sets `family` from it. The `ProviderModel.family`
    wire field already exists.
  - Today's model picker shows `family` as each row's subtitle and one model
    per family by default. Both become true for Codex.
- **D5 Family representative ties.** `DefaultModelSelector` ranks a family's
  models by newest `releaseDate`, then id ascending. Codex sends no release
  dates, so the id rule would pick the oldest (`gpt-5.6-sol` over
  `gpt-6.1-sol`). Ties now keep catalog order, which every plugin sends
  strongest and newest first. This takes a stable sort by catalog index,
  because Dart's `List.sort` is not stable.
- **D6 Released apps (decided without asking; the owner can veto).** A released
  app talking to a bridge with D4 still ranks ties by id. Its Codex model
  picker would then show the oldest model of each family by default, with the
  rest under its existing "show all". The selected model and the default model
  (`isDefault`) are unaffected. That is a display imperfection that ends when
  the app updates, not a broken flow, so phase 1 accepts it rather than adding
  version negotiation.
- **D7 Tapping a model name** selects that model at today's switch rule: the
  current level when the model offers it, otherwise the model's default.
  Round 15 described "its last-used level"; a per-model memory needs new state,
  so phase 1 uses the existing rule *(decided without asking; the owner can
  veto)*.
- **D8 Look and motion (rounds 12–15).**
  - Chip: a metal plate with a medallion at the left showing a fan of blades,
    one per level, lit up to the current level; model name with the level word
    under it in small caps; an end diamond that becomes a bolt when fast mode is
    on. Silver for standard speed, gold for fast. While the composer is
    read-only (launch hand-off), the same chip is shown locked, so nothing
    swaps or shifts.
  - Picker: rings centred near the chip at the bottom-left; one ray per
    ladder level any ring offers, from the lowest (OFF, MINIMAL or LOW, lower
    angle) to the highest (MAX or ULTRA); ULTRA gets its own ray.
  - Only the current choice is drawn: the medallion on its dot and a polished
    trail along its ring up to it. Every other dot is the same hollow 11 pt
    dot.
  - Ripple entry, about 0.34 s, no overshoot: one ripple leaves the medallion
    and rings settle from the inside out, each growing only the last few
    percent. With reduced motion it is a plain fade.
  - Touch areas: each dot owns a ring patch about 55 pt deep that reaches
    halfway to its neighbours. They are invisible in production (the review
    page's outlines were review-only).
  - The dot under the finger grows while sliding, with a selection haptic each
    time the finger enters a new patch. Release on a patch picks it; release
    outside cancels. A tap on a patch also picks it. Taps are never ignored: a
    blocked pick shows the reason.
  - Model names sit inside their rings along the arc. The FAST tag next to a
    name is hidden when every ring model has fast mode.
  - Fast mode toggle in the bottom-right corner of the picker, using today's
    fast-mode decision and cache-reset confirmation.
- **D9 No sound, no analytics event in phase 1.** The chosen model and effort
  are not reported today, and adding them is a separate analytics decision.
- **D10 Round 17.**
  - Dark mode, variant C "tinted bead": hollow dots and the "All N models"
    pill fill with `fgQuaternary` and a `fgSecondary` edge, and the level
    words use `textTertiary`. Light mode is unchanged.
  - `off` joins the ladder as its weakest level, so Pi and Oh My Pi qualify.
    OFF has no blade on the medallion and lights none.
  - "All N models" opens the model picker listing every model, not one per
    family; the model pill's picker is unchanged.

## Current behaviour (origin/main fc48f071ef, 2026-11-13)

- `AgentModelButtons`
  (`client/module_app_ui/lib/src/features/session_detail/widgets/agent_model_buttons.dart`)
  renders the agent, model (`_ModelMenu` → `ModelPicker` in a
  `PregoPickerPopover`), variant (`_VariantMenu`, raw id) and fast pills
  (`_FastModeButton` with `_confirmCacheReset`). Callers:
  `session_detail_composer_controls.dart` and `new_session_view.dart`, both
  tearing off `cubit.selectModel` as `onModelSelected`, typed
  `void Function({required String providerID, required String modelID})` in
  `agent_model_buttons.dart`, `_ModelMenu` and `model_picker.dart`.
- Session detail: `SessionDetailCubit.selectModel` (l.3634) keeps the previous
  variant when the new model offers it, otherwise the default, and
  `selectVariant` sets the variant; model and effort take two emits today.
  `SessionDetailComposerControls` shows the composer read-only from
  `LaunchSessionComposerSource` until the session loads;
  `SessionLaunchComposerX` (`session_detail_state.dart` ~l.248) exposes
  `fastModeControl` for it.
- New session: `NewSessionCubit.selectModel` (l.1090) calls
  `NewSessionOptionsService.selectModel` (l.383), which applies the remembered
  `NewSessionVariantIntent` last. Only `selectVariant` records an intent
  (`_selectionTracker.recordVariant`). Option pills read `AgentModelData`,
  built in `NewSessionComposeConfigAgentModel.agentModelData`
  (`new_session_state.dart` l.211–245).
- States expose derived values through getters backed by const calculators,
  for example `fastModeControl` via `FastModeToggleCalculator`.
- `SessionSelectionCalculator.availableVariants` drops `none`; variant order is
  the plugin's, strongest first.
- `CatalogStrengthOrder.models` orders models by vendor, then newest
  generation, then tier (Astra, Sol, Terra, Luna, bare, other suffixes); its
  `_rank` already parses OpenAI ids.
- Codex and Claude plugins set `family: null`. Claude keeps separate entries
  per context window (`opus`, `opus[1m]`).
- No radial picker exists. `prompt_input.dart` already plays
  `HapticFeedback.selectionClick` during the voice-hold drag.

## Design

### Bridge (plugin interface and Codex plugin)

- `CatalogStrengthOrder.openAiFamily(String id)` per D4, sharing the parse
  with `_rank` so family and ordering cannot disagree.
- `CodexModelRepository` passes `family: CatalogStrengthOrder.openAiFamily(id)`.

### Core (module_core, pure Dart)

- `client/module_core/lib/src/foundation/models/session_options/`:
  - `EffortLevel` enum (`minimal … ultra`) with `tryParse` for wire variant
    strings. Closed set, parsed at the boundary.
  - `OrbitRing`: `providerID`, `modelID`, `name`, its levels (each an
    `EffortLevel` with the original `SessionVariant`), and its
    `FastModeSupport`.
  - `ModelOrbits`: `rings` (outermost first), `levels` (ladder levels any ring
    offers, in ladder order), `totalModels`, `allRingsFast`, a non-nullable
    `current` ring and `EffortLevel? currentLevel` (null for a model with no
    levels). The widgets derive nothing.
- `client/module_core/lib/src/services/model_orbits_calculator.dart`: const
  `ModelOrbitsCalculator` building `ModelOrbits?` per D1 and D2, null when the
  catalog is not orbit-shaped or no model is selected.
- `DefaultModelSelector`: catalog-order tie-break (D5).
- Exposure: `SessionDetailLoaded` and `SessionLaunchComposerX` get a
  `modelOrbits` getter (the `fastModeControl` pattern); `AgentModelData` gets a
  `modelOrbits` field filled in `NewSessionComposeConfigAgentModel.agentModelData`.
- Model plus level in one action:
  - `SessionSelectionCalculator` gets one method resolving a model switch's
    variant: the requested variant if the model offers it, else the previous
    one if offered, else the default.
  - `SessionDetailCubit.selectModel` takes `required SessionVariant? variant`,
    calls that method and emits once.
  - `NewSessionOptionsService.selectModel` takes the same parameter, and an
    explicit variant wins over the remembered intent;
    `NewSessionCubit.selectModel` records the variant intent whenever one is
    passed, so a later model switch does not bring back a stale level.
  - The `onModelSelected` callback type gains `required SessionVariant?
    variant` in `agent_model_buttons.dart`, `_ModelMenu` and
    `model_picker.dart`; `ModelPicker` passes null.

### UI (module_app_ui, `features/session_detail/widgets/model_effort/`)

- `MedallionChip`: the chip from D8, a `CustomPaint` plus text, with a locked
  look for `readOnly`.
- `OrbitGeometry`: a pure class for ring radii, ray angles, patch bounds and
  the hit test, shared by painter and gestures, with unit tests.
- `OrbitsPicker`: an overlay route from the chip with a scrim, a
  `CustomPainter`, an `AnimationController` for the ripple, and one gesture
  layer that tracks the pointer, grows the dot under it, plays the haptic on
  patch change, and on release or tap calls `onModelSelected(providerID,
  modelID, variant)` and closes.
- `showFastModeConfirmation`: the existing `_confirmCacheReset` flow extracted
  as a top-level function, used by `_FastModeButton` and the picker's toggle.
- `AgentModelButtons`: when `!compact` and `modelOrbits != null`, render the
  chip instead of the model, variant and fast pills, locked when `readOnly`.
  `ReadOnlyAgentModelPills` (archived and sub-agent pages) is unchanged.

## Compatibility

- No wire shape change.
- New app, old bridge: `family: null`, so every model is its own family and
  the rings are the first four models, with the current model in the fourth
  place when it is not among them (round 16's accepted fallback).
- Old app, new bridge: Codex model rows gain a family subtitle and group by
  family, with the oldest of each family shown by default (D6).

## Complexity budget

- New mutable state: the picker overlay's animation controller and the index
  of the patch under the finger, both widget-local and disposed with the
  overlay. Nothing persisted, no new cubit fields.
- Not added: per-model last-used level memory (D7), a plugin capability flag
  (D1), any wire field, version negotiation for released apps (D6), aliases
  for non-ladder effort names (multi-provider catalogs are not eligible).
- `ModelOrbits` is recomputed on composer rebuilds; it is a pass over a
  handful of models. Memoize only if profiling shows a cost.

## Cleanup

- `_VariantMenu` and `_FastModeButton` stay: the pointer layout and non-orbit
  catalogs still use them. The fast-mode confirmation is extracted, not
  duplicated.
- No other obsolete code found.

## Steps

### Step 1 — Raise the plan (🌱)

This file and the tracker.

### Step 2 — Codex model families (🌿)

`openAiFamily` with tests over the Codex fixture ids (`gpt-6-astra`,
`gpt-5.6-sol`, `gpt-5.5`, `gpt-5.4-mini`, `gpt-5.6-codex-mini`,
`gpt-default`, a namespaced and a `[…]` id), `CodexModelRepository` using it,
and the `DefaultModelSelector` tie-break with a test. Expected result: Codex's
model picker shows the newest model of each family by default, with the family
as subtitle. Independent of step 3.

### Step 3 — Orbit model and selection (⚙️)

`EffortLevel`, `OrbitRing`, `ModelOrbits`, `ModelOrbitsCalculator`, the
exposure points, the selection method and the `selectModel(variant:)` change
on both cubits and the service, plus the callback type in module_app_ui so the
tear-offs compile. Tests: calculator (eligibility, family representatives, the
current-model swap, null-family fallback, `none` ignored, an unknown level
rejects the catalog, no selection gives null), the single emit, and the
new-session intent recording. No user-visible change.

### Step 4 — Orbits picker (🚧)

`OrbitGeometry`, `OrbitsPicker` with painter, ripple, gestures, haptics, FAST
tags, fast toggle, "All N models", and semantics (each patch a labelled
button). Widget tests for tap, slide-release, release-outside and the "All"
entry; PR visuals come from widget-test goldens, with no demo screen in
production code. Not mounted yet, so no user-visible change.

### Step 5 — Medallion chip in the composer (⚙️)

`MedallionChip`, `showFastModeConfirmation`, mounting in `AgentModelButtons`
for the touch layout including the locked read-only chip, and the
"All N models" hand-off to `ModelPicker`. Before and after captures plus a
short recording in the PR.

### Step 6 — Regression documents (🌱)

`docs/regression/session-creation-and-options.md`: chip, orbits, eligibility,
rings rule, gestures, the launch hand-off chip, the Codex family grouping
in the model picker, and the first-listed default for undated catalogs.
`docs/HARNESS_CAPABILITIES.md`: a row saying which harnesses get the orbits on
the touch composer (Claude Code, Codex) and that the others keep the pills
until the list sheet lands.

### Step 7 — Dark beads, OFF level and the full model list (⚙️)

D10: the dark palette, `EffortLevel.off` with its ray word, chip word, blade
rule and screen-reader label, and the model picker listing every model when
opened from the orbits. Docs follow.

### Step 8 — L3 matrix and retirement (🌱)

Run the matrix below, record it, move the plan to `.plan/completed/`.

## Verification and regression matrix

Highest level: L3 Release for the touched behaviour, on a headless iOS
simulator against a local bridge (live harnesses through the local test
proxy where they accept it).

| Cell | Check |
|---|---|
| Claude Code, iOS simulator, light and dark | Chip shows model and level; orbits open with the ripple; slide and release picks model and level in one go; a no-level model ring works; fast toggle with confirmation; the sent prompt carries the picked variant and fast mode. |
| Codex, iOS simulator | Rings are the latest model of each family; "All N models" opens the regular picker listing every model; picking a model outside the top four makes it take the fourth slot, with the rings kept in strength order (strongest outermost), so it is not necessarily drawn innermost; FAST tags hidden when every ring has fast mode. |
| New session to session detail, iOS simulator | Both composers behave the same; during the launch hand-off the locked chip stays in place with no swap. |
| Pi with one provider, iOS simulator | Orbits with an OFF ray; picking OFF sends `off`, and the chip reads OFF with no blade lit. |
| One non-orbit harness (OpenCode with several providers, or Hermes), iOS simulator | Today's pills, unchanged. |

## Risks and accepted behaviour

- Released apps show the oldest Codex model of each family by default after
  the bridge updates (D6). Accepted.
- D5 applies to every harness, but only decides a starting model when the
  catalog has no available `defaultModelID` and no release dates. Plugins that
  supply a default (Claude Code, Pi, Codex) keep it. Such a catalog now starts
  on its first-listed model, which plugins sort strongest and newest first,
  instead of the alphabetically first id; a remembered pick still wins.
  Accepted as an improvement; covered by step 2's selector unit tests.
- Mixed generations in the rings (for example GPT-6.1 Sol outermost, GPT-6
  Astra inside) follow catalog order rather than tier strength. Accepted; the
  catalog order is the shared strongest-first rule.
- Claude Code reports no families, so a catalog with more than four models
  uses the fallback. See later phases.

## Later phases (rough intent only)

- Other harnesses: the model list sheet with an effort footer (round 10,
  option A), which also becomes the "All N models" destination.
- Pointer layout (desktop): adapt the chip and picker to mouse and keyboard.
- Claude Code families and context-window variants, if its ring fallback
  turns out to hide models people use.
- Per-model last-used level (D7), if the owner wants it.

## Plan review record

- 2026-11-13 `architecture-plan-review`: rejected with nine findings, all
  applied: catalog-order tie-break and the released-app effect (D5, D6), the
  family subtitle (D4), the new-session intent path, the selection rule in
  `SessionSelectionCalculator` with `SessionVariant?`, the callback type in
  step 3, the current choice on `ModelOrbits` and its exposure points, the
  locked chip during the launch hand-off gated on `compact`, `openAiFamily`
  sharing the existing parse, and concrete names and paths.

## Open questions

None.
