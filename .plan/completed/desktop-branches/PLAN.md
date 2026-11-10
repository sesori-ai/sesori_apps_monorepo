# Desktop branches in shared client code

Slug: `desktop-branches`. PR titles: `<emoji> [desktop-branches] <description> [step x/7]`.

Status: completed 2026-11-09. Step 7 ran the matrix (#2489). #2490 recorded the owner's round 4 answers and retired
the plan with the owner's [acceptance of the reduced matrix](#owners-acceptance-of-the-reduced-matrix-2026-11-09).
Six desktop items stay open after retirement, owed to the owner's own check. The waiting-dot amber, also open at
retirement, was decided later the same day (see "Open after retirement").
Later phases start their own plans from the bullets at the end.

## Goal, evidence and scope

Shared client code (`client/module_app_ui`, `client/module_prego`) asks "is this desktop?" in about 100 places.
A widget reads the interaction mode, then picks a value, a behaviour or a layout inline. Every such read is a fork
that a later phone change can miss. Most of them came in one desktop pass (#2429).

The end goal is about 12 allowlisted reads in about 10 files. The owner approved this rule on 2026-11-09: a desktop
difference lives in exactly one of three homes.

| Home | What lives there | Examples |
| --- | --- | --- |
| Metrics | Values: sizes, radii, colours, durations, weights. Each component gets a touch set and a desktop set, chosen once when the shell builds its theme. | row height, panel radius, label weight |
| Wrapper | Behaviour: a widget that adds hover, right-click or a hit target on desktop and does nothing on touch. | hover reveal, context-menu region, touch target |
| Variant | Structure: a separate desktop widget, chosen at one switch, sharing the computed state. | session row, composer layout |

A lint rule in `shared/no_slop_linter` enforces the rule, with a short allowlist.

The phone keeps its touch look and its wide (foldable) layout. No desktop look moves to the phone unless a decision
below says so. Phase 1 does not touch the wide layout.

### What counts as a read

On `origin/main` `478ea1c15e`, 105 reads in 46 files, not counting the files that define the modes
(`interactions/prego_interaction_scope.dart`, `theme/prego_design_system.dart`):

- 86 `PregoInteractionScope` reads: `PregoInteractionScope.of(context)` or an inherited-widget lookup of
  `PregoInteractionScope`, compared with `PregoInteractionMode.pointer`;
- 7 `PregoDesignSystem.isDesktopScale` reads: `markdown_styles.dart` (4), `prego_popup_alerts_notifications.dart`,
  `prego_anchor_menu.dart` `_titleStyle`, `prego_surfaces.dart`;
- 12 `ComposerPresentation.pointer` or `.touch` reads: `prompt_input.dart` (10),
  `session_detail_composer_controls.dart`, `new_session_view.dart`.

The evidence is an audit of `origin/main` `9ba5d63d10` (2026-11-09). Its line numbers are stale, so this plan names
every site by file and symbol, checked against `478ea1c15e`.

### Phase 1 scope

Phase 1 is this plan's detailed part:
- fold the differences the owner decided to one value;
- add the lint rule, so no new read lands without a marker.

It adds no metrics objects, wrappers or variants. It removes about 30 reads, leaving about 71 in about 35 files.
Later phases are rough bullets at the end. Each becomes its own plan when it starts.

### Done or in flight outside this series

- Merged: #2449, #2451, #2452 and #2453 (`session-row-states`, merged 2026-11-09). `session_tile.dart` and
  `all_sessions_list.dart` are free again.
- #2460 (open) is a precursor, not a series step. It removes four reads:
  - `floating_sidebar_panel.dart` `FloatingSidebarPanel`: the pointer fill;
  - `sessions_home_view.dart` `_HomeComputerButton`: the scope read and its tooltip;
  - `transcript_motion.dart` `_TranscriptPresenceState`: the enter duration, plus the unused
    `pregoContentMoveDuration`;
  - `prego_picker_search_list.dart` `_Heading`: the double scope read; it now uses its `pointer` parameter.

  #2460 also owns the phone "Waiting" label in `session_tile.dart` `_statusLabel`, which takes the darker amber
  (`pointerWarningText`). That change is not in #2460's diff at `da699077fb`. Step 2 checks; if #2460 merges without
  it, step 2 folds it.
- `desktop-text-size` (a local branch, no PR yet) changes `prego_text_theme.dart`, `session_diffs_view.dart`,
  `diff_file_header_delegate.dart`, l10n, desktop shell files and the menu width in `prego_anchor_menu.dart`
  `_flatPanel`. Step 4 changes another hunk of `prego_anchor_menu.dart` (`_flatEntry`). Whichever lands second rebases.

### Rules for every step

- **Verify both sides before folding.** The audit called ten sites "no-ops", and five of them would have changed
  something visible (see [Not folds](#not-folds-corrections-to-the-audit)). Before changing a site, read both
  branches and confirm what each platform shows today. A site that turns out different from this plan is dropped
  and noted in the tracker, never forced through.
- **The phone keeps its look**, except where a decision below changes it.
- **Docs in the same PR.** Each PR updates the `docs/regression/` documents its change affects. Step 6 only
  reconciles what is still inconsistent across documents.
- **Visuals.** UI PRs carry before and after images on the `pr-media` branch, built from fixture data only. The
  repository is public.
- **On-screen checks** run on a headless iOS simulator: `xcrun simctl boot`, never opening Simulator.app, on the slot
  simulator the local testing setup assigns (`sesori-dev-{x}`, iPhone 17). A macOS desktop check runs only in a step
  that changes what desktop shows; each step says whether it does. No Android or real-device checks.
- **New findings** follow the findings rule. Fix one that follows from a decision or a rule. Put a real design choice
  on a review page. Never leave one silently.
- **No new mutable state** in phase 1.
- **After step 5,** a PR that removes a read deletes its marker, and a PR that has to add a read adds a marker that
  names its home (see step 5).

## Decisions

### Owner decisions (2026-11-09)

Final. Where the owner reverses the audit's suggestion, the plan follows the owner.

| # | Difference | Decision | Audit suggested | Step |
| --- | --- | --- | --- | --- |
| 1 | Transcript and picker state icons. Desktop replaced robot, terminal, tool and the static AI loader with check, tool and bulb. | Phone's icons on both. #2429's desktop replacements are reverted. | Desktop's icons. **Owner reverses.** | 3 |
| 2 | Commands and paths in step rows. Desktop sets them in monospace. | Phone's look on both: commands underlined, monospace reverted. | Monospace on both. **Owner reverses.** | 3 |
| 3 | Needs-you cards grow in and fold away (desktop only today). | Animate on both. | Same | 3 |
| 4 | Computer entry at the top of Settings. Desktop puts it in a card. | Card on both. | Same | 4 |
| 5 | Popup alert accent. Touch shows a glow in the variant colour behind the card. | Icon only on both. | Same | 4 |
| 6 | Diff list "M" letter. Desktop is grey; touch is amber. | Grey on both. | Same | 4 |
| 7 | Menu and picker section headings. Desktop uses sentence case. | Spaced capitals (uppercase, 0.8 tracking) on both. Sentence case reverted. Amended: the New Session harness menu's "Harnesses" title takes it too (round 4 below). | Pick one, no side. **Owner picks the phone's.** | 4; the title in #2490 |
| 8 | Inline code in chat. Desktop has no background. | Background (`alphaBlack10`) on both. | Pick one | 3 |
| 9 | Desktop harness overview cards (`bgSurface3`). | `bgSurface2` on both, matching harness detail and MCP. | Same | 4 |
| 10 | Needs-you card rules. | Desktop's rules on both: only the first card's action is primary, 72 pt minimum action width, the darker readable amber label, desktop's alphas, padding and icon size. Amended: the phone keeps its own button looks (choice C, round 2 below). | Same | 3 |
| 11 | The subtle differences: motion timing, 1–4 pt nudges, colour tweaks. | Fold all in one batch, one value each. | Same | 2 |
| 12 | Order. | Folds and lint first. Metrics objects and variants later. | Same | — |

### Owner decisions, review round 2 (2026-11-09)

These refine steps 3 and 4.

- **Decision 5, the popup alert accent.** On the phone the accent is a soft coloured glow behind the card, not a
  stripe. Decided: no glow on both.
- **Decision 10, the needs-you card rules.** Desktop's rules on both, including the button looks: the first card's
  action is the solid primary, the others are secondary. Before step 3 merges, check that the secondary button is
  legible on the amber tint on the phone in dark mode. If it is unreadable, fix it for both apps and show the owner.
  After step 3 the owner chose C, "The before is better": the phone keeps its old buttons (light: both secondary;
  dark: both white), desktop keeps this rule; the rest of decision 10 stays on both.
- **Decision 2, reading confirmed.** Only shell commands are underlined and paths stay plain, on both. The needs-you
  request line is normal text on both.

### Owner decisions, round 3 (2026-11-09)

Two items step 2 dropped as the owner's call, now decided and folded in step 4.

- **Item 2.10, the popup alert under Reduce Motion.** A gentle fade on both: with Reduce Motion on, desktop fades the
  alert as the phone does instead of turning solid within 40 ms. Without Reduce Motion nothing changes on either, so
  the pointer check stays for that path.
- **Item 2.14, the waiting dot.** The phone's amber (`fgWarningPrimary`) on every waiting dot on both: the session
  row's, and on desktop the page title's and the hidden sidebar toggle's, so desktop never shows two ambers.

### Owner decisions, round 4 (2026-11-09)

The two questions step 7 left with the owner, answered on the review page.

- **Decision 7 amended: the "Harnesses" menu title.** The New Session harness menu opens with a title row, "Harnesses"
  and a settings button (`_HarnessesMenuHeader` in `new_session_plugin_chooser.dart`). It is not a `PregoMenuLabel`,
  so step 4 left it in sentence case. The owner chose spaced capitals on both apps, with the same size, colour and
  spacing as the model picker's "RECENT". The row's layout and its settings button stay. #2490 gives it
  `PregoMenuLabel.textStyle`, the one style every menu and picker section heading now shares, and uppercases its
  text at render as the other headings do; the localized string stays "Harnesses". No other menu or picker has a
  title row with an action beside it.
- **Retire now.** The owner chose "Retire now, I check these when I try the build". The acceptance is written under
  [Verification and retirement](#owners-acceptance-of-the-reduced-matrix-2026-11-09).

### How this plan reads the decisions

Each reading below follows the decision text against what the code does. A reviewer who reads one differently says so
on the step's PR.

- **Paths stay plain (decision 2).** The phone underlines shell commands, but shows paths and patterns as plain text
  (`_ToolHeader.build`, `final title => TextSpan(text: title)`). "Phone's look" therefore means underlined commands
  and plain paths on both. The owner confirmed this reading in round 2.
- **The needs-you request line follows decision 2, not 10.** Desktop sets a permission's request line in monospace
  (`SessionDetailNeedsYouCard`, `requestIsCode`). The audit grouped it with decision 2, so it becomes
  `textSm.medium` on both, and `requestIsCode` goes away.
- **The alert "accent" is a glow, not a stripe (decision 5).** `_buildAccent` paints a wide radial gradient behind
  the card. Removing it removes the glow.
- **Decision 10 changes the phone's pills.** Today the touch pill is a white pill in both themes: `secondary` in
  light, `primaryAlt` in dark. With desktop's rules, the leading card's action is `primaryAlt` (black in light,
  white in dark), and any other card's is `secondary` (grey in dark). The code comment says the dark grey
  `secondary` "is lost on the tint". Desktop already shows that today. Step 3 checks it on the phone in dark mode
  before it merges; if it is unreadable, step 3 fixes it for both apps and shows the owner (round 2). Amended after
  step 3: by choice C the phone keeps the white pill in both themes, and only desktop leads with one card (#2486).
- **The computer card moves inside the entry (decision 4).** `ComputerSettingsEntry` renders nothing until the
  account's list names the current computer. Desktop builds the card outside it, so desktop flashes an empty card
  while the list loads. Step 4 builds the card inside the entry's computer branch, which also fixes the flash.
- **`session-turns.md` already claims decision 8.** It says the inline code chip looks the same on phone and desktop,
  which is not true today. Step 3 makes it true.

### Not folds (corrections to the audit)

The audit called these no-ops. They are not: each would change something visible. They stay as they are in phase 1
and become metrics values later.

- `transcript_group_widget.dart`: the `visualDensity` branch. Density also shrinks the minimum size, so removing it
  grows the group from 28 to 36 pt on desktop.
- `diff_file_list.dart` `DiffStatusLetter` and `markdown_styles.dart` (`isDesktopScale`): the `w500` overrides. The
  phone's bold is `w700`, not `w600`, so folding changes the phone's weight for fallback fonts.
- `transcript_live_row.dart` `TranscriptStepRow.build`: the strut. The phone has no strut, and forcing one squashes
  lines that hold emoji or CJK text.
- `prego_popup_alerts_notifications.dart` `PregoPopupAlertsNotifications.build`: the `isDesktopScale` read that picks
  the forced dark theme. Removing it needs a "dark variant of this type scale" helper, or it leaves a fragile
  dark-on-dark default.

## Phase 1 steps

| Step | Title | Reads removed | Size | After |
| --- | --- | --- | --- | --- |
| 1 | `🌱 [desktop-branches] Raise the plan [step 1/7]` | 0 | plan files | — |
| 2 | `🌿 [desktop-branches] Fold the subtle desktop differences to one value [step 2/7]` | about 13 | ~300 | #2460 |
| 3 | `🌿 [desktop-branches] Fold the transcript and needs-you card looks [step 3/7]` | 10 | ~400 | step 2 |
| 4 | `🌿 [desktop-branches] Fold the settings, alert, diff and picker looks [step 4/7]` | 8 (7, plus 2.14's from round 3) | ~300 | step 2 (parallel with 3) |
| 5 | `⚙️ [desktop-branches] Flag new interaction-mode reads in shared client code [step 5/7]` | 0 (marks about 71) | ~500 | steps 3 and 4 |
| 6 | `🌱 [desktop-branches] Reconcile regression docs [step 6/7]` | 0 | docs | step 5 |
| 7 | `🌱 [desktop-branches] Run the verification matrix and retire the plan [step 7/7]` | 0 | plan files | step 6 |

Steps 2–4 wait for #2460: they share `transcript_motion.dart`, `session_tile.dart` and
`prego_picker_search_list.dart` with it. Step 3 waits for step 2, because the bash step's label colour follows step
2's call on the settled-label colour. Step 4 waits for step 2, because both change the alert and harness files.

### Step 2: fold the subtle desktop differences

Decision 11. One value per item. Folding deletes the branch, and the read goes when its last use goes.

**Measure before folding, every item.** For each item:
1. read both branches in the code;
2. measure each side: sizes with `tester.getSize` or on screen, colours as hex values, motion from the code;
3. record the before and after in the PR body, one line per item.

Drop an item from the batch when it turns out visible beyond "subtle": a size change over 4 pt, a colour change a
reader would name, a motion change a reader would notice, or a difference this plan did not describe. Leave a
dropped item's branch as it is, and note it in the tracker for the metrics phase.

| Item | Site (file, symbol) | Touch today | Pointer today | Folded value |
| --- | --- | --- | --- | --- |
| 2.1 | `transcript_motion.dart` `_TranscriptPresenceState._animation` | exit 200 ms, `transcriptMotionCurve` (easeOut) | exit 130 ms (`pregoPointerExitDuration`), `pregoContentMoveCurve` | the phone's on both. Planned as the pointer's, but that pair moves the rows above a Working handoff by 6.4 pt (tracker) |
| 2.2 | `transcript_motion.dart` `_TranscriptPresenceState.build` opacity | follows the animation | solid by 35% of the enter | pointer's on both |
| 2.3 | `transcript_disclosure.dart` `_TranscriptDisclosureState` (`_pointer`) | 200 ms easeOut, header minimum 44×44 | open 180 ms, close 130 ms, `Cubic(0.25, 0.55, 0.2, 1)`, resize 180 ms, header minimum zero | pointer's motion on both; `Size(44, 44)` header minimum on both, which density shrinks on desktop (measure the desktop header) |
| 2.4 | `transcript_live_row.dart` `TranscriptLiveLabel.build` shimmer base | `textTertiary` | `textSecondary` | `textSecondary` |
| 2.5 | `transcript_live_row.dart` `TranscriptStepRow.verticalInset` | `(44 + density.dy − 20) / 2` | 2 | the formula on both; desktop density gives 4, so desktop step rows grow by 4 pt. `TranscriptWorkingRow.heightAsFirstRow` follows. |
| 2.6 | `transcript_live_row.dart` `TranscriptStepRow.build` settled label colour | the row colour (`textSecondary`) | `textPrimary` when no colour is passed | `textPrimary` on both. This changes every settled step label on the phone; drop it if it reads as more than subtle. |
| 2.7 | `transcript_live_row.dart` `TranscriptStepRow.build` label–detail space | plain space | space with `letterSpacing: 3` | plain space |
| 2.8 | `transcript_live_row.dart` `TranscriptStepRow.build` leading slot | centred | nudged up 1 pt | centred |
| 2.9 | `prego_button_trailing.dart` `PregoButtonTrailing.build` | fade and size switch, 200 ms | content changes at once, only the width eases (130 ms) | pointer's on both, so a session switch does not animate counts |
| 2.10 | `prego_popup_alerts_notifications.dart` `_PregoPopupAlertOverlayState.build` fade | follows the controller | `_opacity`, solid within 40 ms | `_opacity` on both. Dropped in step 2; round 3 decided the reverse under Reduce Motion (step 4) |
| 2.11 | `prego_popup_alerts_notifications.dart` `_buildCard` radius, dark fill, wrap | radius 16, fill `_surfaceColor` (`#333333`), actions wrap to the start | radius 12, fill `bgSurface3`, actions wrap to the end | radius 12 and wrap to the end on both. Fill: the phone's dark `bgSurface3` is `gray800`, not `#333333`; fold only to a fill that reads the same on both, else drop the fill. The accent use stays for step 4. |
| 2.12 | `composer_live_words.dart` `_ComposerLiveWordsState._liveLook` radius | 18 (`_panelRadius`) | 16 | 16 |
| 2.13 | `harnesses_settings_view.dart` `_HarnessOverviewRow.build` chevron | icon in a 44×44 box | bare icon | bare icon; the whole row is the tap target, and `minHeight: 68` keeps the phone row's height (measure it) |
| 2.14 | `session_tile.dart` `_state` waiting dot | `fgWarningPrimary` | `pointerWarningFill` (light `#D98200` vs `#DC6803`; dark identical) | `fgWarningPrimary` on both. Dropped in step 2; round 3 decided it with desktop's other waiting dots (step 4) |
| 2.15 | `session_tile.dart` `_statusLabel` "Waiting" word | only if #2460 merged without it | | `pointerWarningText` on both |

Cleanup in this step: the `AnimatedSwitcher` path and `_duration` in `PregoButtonTrailing`; `_panelRadius`; stale
doc comments on `TranscriptLiveLabel`, `TranscriptStepRow` and the harness chevron.

Tests: update the tests that pin the old values (`transcript_step_row_test.dart`, `transcript_group_widget_test.dart`,
`session_detail_message_list_test.dart`, `composer_live_words_glide_test.dart`, `prego_popup_alerts_notifications_test.dart`,
`session_tile_states_test.dart`, `harnesses_settings_view_test.dart`; grep for the rest). For each colour fold, one
widget check pumps the widget under both scopes and expects the one value. Motion and nudge folds are proved by the
measurements, not by new tests.

Docs: `tools-and-file-changes.md` (the fold "animated over 200 ms", the panel that "eases open and shut over 200 ms"),
`popup-alerts.md` and `desktop-cockpit-shell.md` (alert fade), `projects-and-sessions.md` (waiting dot, if it names
the colour).

Checks: phone, yes (motion, shimmer, label colour, trailing counts, live-words radius, alert fade, radius and wrap).
Desktop, yes: step rows grow by 4 pt, the disclosure header's size, the label spacing and the leading glyph change
there.

### Step 3: fold the transcript and needs-you card looks

Decisions 1, 2, 3, 8 and 10.

| Site (file, symbol) | Change on both | Phone | Desktop |
| --- | --- | --- | --- |
| `agent_model_buttons.dart` `ReadOnlyAgentModelPills.build` agent pill icon, `_AgentMenu.build` `leadingIcon` | `TablerRegular.robot` | none | tool → robot |
| `subtask_part_widget.dart` `SubtaskPartWidget` finished icon | `TablerRegular.robot` (`textTertiary`) | none | check → robot |
| `tool_part_widget.dart` `_ToolHeader.build`, bash step | icon `terminal_2` in the step colour; command underlined (`TextDecoration.underline`), not `code`; label colour as step 2 decided (if 2.6 folded: `status == error ? color : null`; if dropped, leave this branch for the metrics phase) | none | check → terminal, mono → underline |
| `tool_part_widget.dart` `_ToolHeader._statusIcon` | `TablerRegular.tool`; delete its `pointer` parameter | none | check → tool |
| `tool_part_widget.dart` `_ToolHeader.build`, title detail | plain `TextSpan(text: title)` | none | mono → plain |
| `reasoning_part_card.dart` `_ReasoningPartCardState` leading | the static `PregoAiLoader` (outline, `textSecondary`). The `maxLines` read stays (metrics). | none | bulb → loader |
| `session_detail_loaded_view.dart` `_NeedsYouCards.build` | `TranscriptPresenceColumn(risesFromBottom: true)` | cards grow in and fold away | none |
| `session_detail_scaffold_sections.dart` `SessionDetailNeedsYouCard.build` | desktop's rules: dark fill alpha 0.07, border alpha 0.24, padding `fromSTEB(lg, md, md, md)`, icon 16, label `pointerWarningText`, action minimum width 72, hierarchy `leads ? primaryAlt : secondary` in both themes; request line `textSm.medium` | all of it (label in light: `#B54708` → `#854B00`) | request line mono → `textSm` |
| `markdown_styles.dart` `buildChatMessageMarkdownStyleSheet` inline code | `backgroundColor: alphaBlack10` | none | gains the chip |

Cleanup in this step:
- `requestIsCode` on `SessionDetailNeedsYouCard`, with its two call sites in `session_detail_loaded_view.dart`;
- the `_statusIcon` `pointer` parameter;
- rename `pointerWarningText` in `prego_colors_x.dart` to `textWarningStrong`, since both platforms use it now; update
  `session_tile.dart` too;
- stale doc comments on `_NeedsYouCards`, on the bash detail ("a command reads as a command under a pointer") and on
  the needs-you pill ("a white pill in both themes").

Tests: `tool_part_widget_test.dart` (expects `TablerRegular.tool` under a pointer), `agent_model_buttons_test.dart`,
`reasoning_part_card_test.dart`, `chat_message_style_test.dart`, `session_detail_message_list_test.dart`,
`app/test/features/session_detail/widgets/session_detail_body_test.dart`. Add one widget test that pumps two
needs-you cards under touch and expects the leading action `primaryAlt` and the other `secondary`.

Docs: `tools-and-file-changes.md` (step row layout, underlined commands), `session-turns.md` (inline code chip; the
newest row keeps its gap while a needs-you card comes and goes), `questions-and-permissions.md` (the needs-you
card's "white button pill").

Checks: phone, yes. The needs-you card animates and the composer gap holds; the light leading pill is now black; the
dark non-leading grey pill is readable on the tint. Desktop, yes: icons, underlined commands, plain paths, the inline
code chip.

After step 3, #2486 put the phone's pills back by choice C; its touch test expects both cards' actions bright, so
step 7 checks the phone against that, not against the pills above.

### Step 4: fold the settings, alert, diff and picker looks

Decisions 4, 5, 6, 7 and 9, and round 3's items 2.10 and 2.14.

| Site (file, symbol) | Change on both | Phone | Desktop |
| --- | --- | --- | --- |
| `bridge_settings_section.dart` `BridgeSettingsSection.build` and `computer_settings_entry.dart` `ComputerSettingsEntry.build` | the `PregoGroupedRows` card with its `fromSTEB(18, 0, 12, 0)` padding and the `md` gap after it, built inside the entry's computer branch; bottom gap 0; selector icon `sm` | flat row → card | no empty card while the list loads |
| `prego_popup_alerts_notifications.dart` `_buildCard` | no accent: delete `_buildAccent`, and `_WideEllipseGradientTransform` if nothing else uses it | glow gone | none |
| `diff_file_list.dart` `DiffStatusLetter.build` "M" | `textSecondary`. The weight read stays (see Not folds). | amber → grey | none |
| `prego_picker_search_list.dart` `_Heading` | `text.toUpperCase()`, `letterSpacing: 0.8`. The padding keeps its `pointer` parameter (metrics). | none | sentence case → capitals |
| `prego_anchor_menu.dart` `_flatEntry` `PregoMenuLabel` | `text.toUpperCase()`. The glass path already uppercases. | none | sentence case → capitals |
| `harnesses_settings_view.dart` `_ReadyView` group and defaults cards, `_HarnessActionFeedback` | `color: bgSurface2` | none | `bgSurface3` → `bgSurface2` |
| `prego_popup_alerts_notifications.dart` `_PregoPopupAlertOverlayState.build` fade (2.10) | under Reduce Motion, the fade follows the controller; the pointer's `_opacity` only while the alert slides | none | Reduce Motion: solid at once → the phone's fade |
| `session_tile.dart` `_state`, `desktop_session_signals.dart`, `desktop_cockpit_shell.dart` toggle dot (2.14) | `fgWarningPrimary` | none | light `#D98200` → `#DC6803` |

Cleanup in this step: `_entryGap`; the accent code; the `ComputerSettingsEntry` doc comment ("grows into place");
the `DiffStatusLetter` doc comment if it names amber.

Tests: `app/test/features/settings/settings_screen_test.dart`, `desktop/test/features/settings/desktop_settings_screens_test.dart`,
`computers_view_test.dart`, `harnesses_settings_view_test.dart`, `prego_popup_alerts_notifications_test.dart`,
`prego_anchor_menu_test.dart`, `project_picker_test.dart`. Add one check that the settings entry shows no card while
the current computer is unknown.

Docs: `account-and-onboarding.md` (the computer entry's "flat row under the caption"), `popup-alerts.md` ("icon and
accent treatment"), `desktop-cockpit-shell.md` (alerts "without the accent glow"), `diffs-and-source-control.md`
("plain coloured letter (A, D, M)"), `session-creation-and-options.md` (uppercase provider headings; check the
desktop wording), `plugin-setup-and-lifecycle.md` (shared grouped overview).

Checks: phone, yes (computer card, alert without glow, grey "M"). Desktop, yes: menu and picker headings, harness
cards, the computer card while loading.

### Step 5: flag new interaction-mode reads

A new warning rule, `avoid_interaction_mode_reads`, in `shared/no_slop_linter`.

- **Where it applies.** Libraries under `package:sesori_app_ui/` and `package:theme_prego/`. The product shells
  (`client/app`, `client/desktop`) are free: they choose the mode. Tests are free (`ignoreTestFiles: true`).
- **Exempt files.** The ones that define a mode: `package:theme_prego/interactions/` (the scope, and the wrappers
  later), `package:theme_prego/theme/prego_design_system.dart` (`isDesktopScale`), and
  `package:sesori_app_ui/src/features/session_detail/composer_presentation_scope.dart` (`ComposerPresentation`).
- **What it reports,** once per read, at the read's start:
  1. `PregoInteractionScope.of(...)`;
  2. `getInheritedWidgetOfExactType<PregoInteractionScope>()` and `dependOnInheritedWidgetOfExactType<PregoInteractionScope>()`;
  3. references to `PregoInteractionMode.pointer` or `.touch` (this catches a mode passed in as a value); a
     comparison of a read from 1 or 2 with the enum is one finding;
  4. reads of `PregoDesignSystem.isDesktopScale`;
  5. references to `ComposerPresentation.pointer` or `.touch`.
- **Markers.** Every read left after step 4 gets the house per-line ignore with its home:
  `// ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics` (or `wrapper`, `variant`,
  `presenter`). Reads that stay for good get their final reason instead, such as the presenter in `prego_modal.dart`.
  `git grep -c 'avoid_interaction_mode_reads, pending:'` then counts what the later phases still owe.
- **Why per-line markers.** `ignore_for_file` would hide new reads in the busiest files. An info severity still fails
  `dart analyze --fatal-infos` in CI. A rule that is off by default shows nothing. The repo has no baseline
  mechanism, and per-line ignores with a reason are the house convention.
- **Stale markers.** Check whether `unnecessary_ignore` (enabled in `client/app/all_lint_rules.yaml`) reports a
  plugin ignore whose read is gone. Record the answer in the tracker: if it does, CI forces later PRs to delete
  stale markers; if not, the strict phase greps for them.

Files:
- `shared/no_slop_linter/lib/src/rules/avoid_interaction_mode_reads_rule.dart` on `NoSlopRule`;
- register it in `shared/no_slop_linter/lib/main.dart`, with a line in the header comment;
- `shared/no_slop_linter/test/rules/avoid_interaction_mode_reads_test.dart` on `AnalysisRuleTest`, with fake
  `theme_prego` and `sesori_app_ui` packages: each form reports; exempt files, shell packages and test files do
  not; a marker suppresses;
- about 71 marker lines in about 35 files;
- rewrite the `PregoInteractionScope` doc comment, which says "each widget decides what the mode means for it", to
  name the three homes and the rule;
- add the rule to `client/AGENTS.md` under "Platform Abstraction", in two or three sentences.

Checks: CI analyze is green. The PR body shows that an unmarked read in a shared file fails `dart analyze`. No
on-screen check: nothing visible changes.

### Step 6: reconcile regression docs

Read the documents steps 2–5 touched side by side:
- `tools-and-file-changes.md`, `session-turns.md`, `questions-and-permissions.md`, `popup-alerts.md`;
- `desktop-cockpit-shell.md`, `account-and-onboarding.md`, `diffs-and-source-control.md`;
- `session-creation-and-options.md`, `projects-and-sessions.md`, `plugin-setup-and-lifecycle.md`.

Fix contradictions between them. Remove "desktop only" or "phone only" claims phase 1 made false. Docs only.

### Step 7: run the verification matrix and retire the plan

Run the matrix below on `main` after step 6, and record the result in the tracker. Then move this plan to
`.plan/completed/desktop-branches/`. Later phases start their own plans from the bullets at the end.

Done: #2489 ran the matrix on `main`. Desktop screens was Partial, so the plan waited for the owner. #2490 wrote the
owner's round 4 answers (the "Harnesses" title, and the acceptance below), then moved the plan to
`.plan/completed/`.

## Complexity budget

- New persistent state: none.
- New in-memory mutable state: none. Every fold deletes a branch.
- New analyzer code: one stateless rule.
- Deliberately not added:
  - metrics objects, wrappers and variants (later phases);
  - a baseline or count file for the lint (per-line markers need no new tooling);
  - an annotation-based allowlist (the audit's suggestion): an ignore with a reason is the house form and shows in
    review;
  - a second rule against `pointer*` constructor parameters (the audit's suggestion): it belongs to the strict phase,
    once metrics replace `pointerRadius`, `pointerWidth` and `plain`.

## Cleanup assessment

In this phase, inside the steps that cause it:
- step 2: the `PregoButtonTrailing` switcher path and `_duration`, `_panelRadius`, stale doc comments;
- step 3: `requestIsCode`, the `_statusIcon` `pointer` parameter, the `pointerWarningText` rename, stale doc
  comments;
- step 4: `_entryGap`, `_buildAccent` and `_WideEllipseGradientTransform`, stale doc comments;
- step 5: the `PregoInteractionScope` doc comment.

Deferred to the metrics phase, because a desktop read still uses each one:
- the `prego_pointer_motion.dart` constants (they become theme motion values);
- the `pointer*` colour getters in `PregoColorsX` (they move into the desktop colour set);
- the `pointerRadius`, `pointerWidth` and mode-only `plain` parameters (they become metrics).

## Verification and retirement

Highest level: L2 (Routine), for the regression entries the folded surfaces own. No plugin, packaged or external
service matrix: the change is client presentation only.

| Cell | Where | Steps | What it proves |
| --- | --- | --- | --- |
| Owning tests | `flutter test` in `client/module_app_ui`, `client/module_prego`, `client/app`, `client/desktop`; `dart test` in `shared/no_slop_linter` | every step | the folded values and the rule |
| Analyzer | `dart analyze --fatal-infos` across `client/` | every step; step 5 also shows an unmarked read fails | no new reads, no stray markers |
| Phone screens | headless iOS simulator, slot `sesori-dev-{x}`, iPhone 17, light and dark | 2, 3, 4, and 7 on `main` | phone changes match the decisions; nothing else moved |
| Desktop screens | macOS desktop app, local build | 2, 3, 4, and 7 on `main` | only for these steps, because they change what desktop shows |

The final step re-runs the L2 entries of the docs listed in step 6 on the phone cell, plus the desktop items steps 2–4
listed, on `main`. Any reduction to this matrix needs the owner's acceptance written here before retirement.

### Owner's acceptance of the reduced matrix (2026-11-09)

Step 7 ran the matrix on `main` `d2b38bec4e` (tracker, "Step 7 verification"). Every cell passed except Desktop
screens, which is Partial: no agent launched the running macOS app. On 2026-11-09 the owner accepted that reduction
and chose to retire the plan now: "Retire now, I check these when I try the build". The owner looks at these six
items, listed in the tracker's "Owed" section, when trying the build. Anything off comes back as a normal fix:

1. the computer card's hover and press fill, which take the card's shape, and menu hover;
2. the alert fade end to end with macOS Reduce Motion on and off (widget tests cover both);
3. the waiting dot in the real shell's page title and hidden-sidebar toggle (widget tests cover its colour);
4. the desktop text-size setting at non-default sizes on the folded rows, headings and cards;
5. where the harness menu and other anchored menus land in a real window;
6. step 2's presence and disclosure motion seen live.

Open after retirement:
- Decided after retirement (owner, 2026-11-09): every waiting dot on both apps takes desktop's colour before step 4,
  `#D98200` in light and `#F79009` in dark, from one token, `waitingDot`. This reverses 2.14's light value only;
  `fgWarningPrimary` stays as it is for other warning UI.
- The six items above are owed to the owner's own check.

### Evidence and accepted risk

- Evidence: the audit, re-read site by site against `478ea1c15e`, plus #2460's corrections.
- Risk: a "subtle" fold is more visible than expected. Step 2's measure-and-drop rule covers it.
- Accepted: desktop step rows grow by 4 pt (item 2.5); the desktop disclosure header gains a minimum size (item 2.3).

## Later phases (rough; each becomes its own plan)

- **Metrics objects.** A touch set and a desktop set per component, chosen once when the shell builds its theme. They
  take in:
  - the values in Not folds: the `transcript_group_widget` density, the `w500` overrides, the strut, the alerts' dark
    type scale;
  - any item step 2 drops;
  - the `pointer*` colours and the `prego_pointer_motion.dart` constants;
  - the `pointerRadius`, `pointerWidth` and `plain` parameters.
- **Four desktop variants,** each chosen at one switch with shared computed state: the session row, the composer
  layout (on `ComposerPresentation`), the permission request, and new-session setup. Two reads are marked `variant`
  but fall outside these four: the needs-you card's button look (#2486) and the all-sessions filter chip. For each,
  this phase decides between a fifth variant and metrics values.
- **Behaviour wrappers** in `module_prego/lib/interactions/`: hover reveal, context-menu region, touch target.
- **A popover-or-sheet presenter,** replacing the separate picks in the project picker and the transcript group.
- **Delete `isDesktopScale`** once nothing reads it.
- **Lint strict:** no `pending:` markers left, and the final allowlist with its reasons. Phase 1 ends with 75 reads
  in 37 files: 71 `pending:` markers (by home: `metrics` 44, `variant` 22, `wrapper` 3, `presenter` 2) and 4
  permanent. The tracker's "Step 5 markers" section has the count command. A stale plugin ignore is not reported, so
  a PR that removes a read must delete its marker by hand, and this phase greps for markers with no read under them.

## Plan review

Not run for this plan. Phase 1 changes values and adds one analyzer rule; it adds no runtime structure. Each later
phase (metrics objects, variants, wrappers, presenter) carries the architecture, so each gets its own review when its
plan is written.
