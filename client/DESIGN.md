# Sesori Client Prego Design System

This is an extraction of the existing Flutter/Prego system in `client/module_prego`, `client/app`, and `client/design_catalog`. It documents what exists today so future UI work, especially realtime voice transcript preview in `PromptInput`, extends the current grammar instead of redesigning it.

## 1. Atmosphere & Identity

Sesori feels like a quiet, tactile command surface: light chrome, precise pill controls, and content that scrolls behind transparent navigation and dissolving composer scrims. The signature is Prego's mixed material language: glass is reserved for navigation buttons and scroll-edge chrome, while the composer and working surfaces are solid rounded pills with tokenized borders, low shadows, haptics, and live voice motion.

## 2. Color

### Palette

Use semantic `PregoColors` through `context.prego.colors`. Do not use primitives directly in widgets; primitives are listed only to make the resolved light/dark values inspectable.

| Role | Token | Light | Dark | Usage |
|---|---|---|---|---|
| Screen surface | `bgSurface1` | Gray/200 `#F0F0F0` | Gray/950 `#141414` | Page background, bottom composer scrim base |
| Composer/card fill | `bgSurface2` | Gray/50 `#FCFCFC` | Gray/900 `#1E1E1E` | Composer pill/container, picker pills, `PregoCard` |
| Raised local control | `bgSurface4` | Base/white `#FFFFFF` | Gray/700 `#2C2C2C` | Options accordion, attachment remove badge |
| Primary text | `textPrimary` | Gray/950 `#141414` | Gray/25 `#FDFDFD` | Body, composer prompts, stable transcript text |
| Secondary text | `textSecondary` | Gray/525 `#474747` | Gray/400 `#AEAEAE` | Hints, picker labels, provisional transcript text |
| Tertiary text | `textTertiary` | Gray/450 `#5C5C5C` | Gray/450 `#5C5C5C` | Metadata, quiet statuses |
| Placeholder/subtle text | `textPlaceholderSubtle` | Gray/300 `#E6E6E6` | Gray/700 `#2C2C2C` | Shimmer sweep over transcribing text |
| Primary border | `borderPrimary` | AlphaBlack/200 `0x29000000` | AlphaWhite/900 `0x0AFFFFFF` | Emphasized composer, focused secondary button, badges |
| Secondary border | `borderSecondary` | AlphaBlack/100 `0x14000000` | Gray/600 `#333333` | Subtle composer, cards at rest |
| Tertiary border | `borderTertiary` | AlphaBlack/50 `0x0A000000` | AlphaWhite/900 `0x0AFFFFFF` | Hairlines and list separators |
| Brand action | `bgBrandSolid` | Blue/600 `#005CE5` | Blue/600 `#005CE5` | Primary brand buttons |
| Brand message surface | `bgBrandPrimary` | Blue/50 `#E0EDFF` | Blue/500 `#1472FF` | User message bubble fill |
| Primary-alt action | `fgPrimary` | Gray-dark/900 `#18191B` | Base/white `#FFFFFF` | High-emphasis dark/light send and stop buttons |
| Error fill | `bgErrorSolid` | Error/600 `#D92D20` | Error/600 `#D92D20` | Destructive button/cancel target fill |
| Destructive wash | `bgDestructivePressedAlt` | Error/200 `#FECDCA` | Error/800 `#912018` | Drag-to-cancel gradient in composer pills |
| Success fill | `bgSuccessSolid` | Success/600 `#079455` | Success/600 `#079455` | Success primary action tone |
| Warning fill | `bgWarningSolid` | Warning/600 `#DC6803` | Warning/500 `#F79009` | Warning primary action tone |
| Focus ring | `focusRing` | Blue/500 `#1472FF` | Blue/500 `#1472FF` | Keyboard focus ring |
| Error focus ring | `focusRingError` | Error/500 `#F04438` | Error/500 `#F04438` | Destructive keyboard focus ring |
| Waveform resting dots | `fgQuaternary` | Gray/400 `#AEAEAE` | Gray-dark/600 `#656A71` | Not-yet-recorded waveform slots |

### Rules

- `bgSurface1` is the ambient page plane; composer controls float above it with their own `bgSurface2` surfaces and a bottom scrim that fades from `bgSurface1` at 0.98/0.88 alpha to transparent.
- `PregoComposerSurfaceStyle.subtle` means `borderSecondary`; `PregoComposerSurfaceStyle.emphasized` means `borderPrimary`; both keep the same `bgSurface2` fill and `shadows.xs` depth.
- Use `textPrimary` for stable, user-reviewable content; use `textSecondary` for hints and secondary affordances; use `textTertiary` only for metadata and quiet status labels.
- The voice cancel affordance uses `bgErrorSolid` only at committed cancellation and `bgDestructivePressedAlt` as a translucent drag wash; do not introduce a separate cancel color.
- Light/dark behavior comes from `PregoDesignSystem.light` and `.dark`; widgets must not branch on raw hex values. Reading `Theme.of(context).brightness` is allowed only for existing light/dark checks.

## 3. Typography

### Scale

Prego uses `Satoshi Prego` with generated `PregoTextTheme` variations. Each level exposes `.light` (w300), `.regular` (w400), `.medium` (w500), `.bold` (w700), and `.black` (w900).

| Level | Size / Line | Tracking | Primary Usage |
|---|---:|---:|---|
| `display2xl` | 72 / 90 | -2% | Very large display moments |
| `displayXl` | 60 / 72 | -2% | Large screen titles |
| `displayLg` | 48 / 60 | -2% | Prominent page titles |
| `displayMd` | 36 / 44 | -2% | Major section titles |
| `displaySm` | 30 / 38 | 0 | Page-level headings |
| `displayXs` | 24 / 32 | 0 | Smaller headings |
| `textXl` | 20 / 30 | 0 | Navigation title, larger labels |
| `textLg` | 18 / 28 | 0 | Lead copy |
| `textMd` | 16 / 24 | 0 | Composer hints, button labels at large sizes |
| `textSm` | 14 / 20 | 0 | Text field body, row subtitles, compact buttons |
| `textXs` | 12 / 18 | 0 | Metadata, picker labels, tiny statuses |

### Font Stack

- Primary: `Satoshi Prego`.
- Fallbacks: `.SF UI Text`, `.SF UI Display`, `Roboto`, `Arial`.
- Mono/serif: none in the current Prego contract.

### Rules

- User-authored or assistant content should not use `textXs`; reserve it for labels, metadata, and compact chrome.
- `PromptInput` uses `textSm.regular` inside the expanded text field and `textMd.regular` for pill hints, release hints, transcribing text, and voice preview chrome.
- Button text follows `PregoButtonsSolid`: `sm` uses `textSm.medium`; `md` uses `textSm.bold`; `lg` and `xl` use `textMd.bold`.
- Long labels must ellipsize rather than push controls out of the 44pt composer grid.

## 4. Spacing & Layout

### Spacing Tokens

Use `PregoSpacing` or `context.prego.spacing` for semantic spacing. Values come from Figma spacing primitives and include half steps where existing components require them.

| Token | Value | Usage |
|---|---:|---|
| `none` | 0 | No separation |
| `xxs` | 2 | Tiny badges, thumbnail close offsets |
| `xs` | 4 | Icon-to-label gaps, tight line offsets |
| `sm` | 6 | Composer inner padding, 44pt button centering |
| `md` | 8 | Default row gaps, field vertical padding |
| `lg` | 12 | Button padding, list row internals |
| `xl` | 16 | Screen gutters, card padding, composer horizontal inset |
| `x2l` | 20 | Comfortable horizontal button padding |
| `x3l` | 24 | Large composer corner radius and spacing |
| `x4l` | 32 | Wider page rhythm |
| `x5l` | 40 | Large section rhythm |
| `x6l` | 48 | Voice-first typing container bottom radius context |
| `x7l` | 64 | Major vertical separation |
| `x8l` | 80 | Large hero/empty-state gaps |
| `x9l` | 96 | Extra large page rhythm |
| `x10l` | 128 | Rare wide gaps |
| `x11l` | 160 | Rare widest gaps |

### Radius And Width

| Token | Value | Usage |
|---|---:|---|
| `PregoRadius.md` | 8 | Image thumbnails and small cards |
| `PregoRadius.lg` | 10 | Catalog cards and medium rounded panels |
| `PregoRadius.x2l` | 16 | Message bubbles |
| `PregoRadius.x3l` | 20 | Typing composer top/all corners |
| `PregoRadius.x6l` | 34 | Voice-first typing composer bottom corners |
| `PregoRadius.full` | 9999 | Pills, round icon buttons, composer surfaces |
| `PregoWidths.paragraphMaxWidth` | 720 | Long-form readable width |
| `PregoSpacing.containerPaddingMobile` | 16 | Mobile page gutter |
| `PregoSpacing.containerMaxWidthDesktop` | 1280 | Desktop max content width |

### Rules

- Mobile/product shells use `PregoGlassScaffold` for page chrome; the body may scroll behind the transparent top bar, while the composer is a fixed bottom controls cluster measured into the transcript list inset.
- `SessionDetailLoadedView` positions bottom controls at left/right/bottom 0, then applies 16px horizontal padding around `PromptInput`; background tasks sit directly above and share the active composer surface style.
- The voice composer grid is built around a 44pt action slot, `PregoSpacing.md` row gaps, and `PregoSpacing.sm` inner pill padding. Preserve the slot list during voice interactions so gesture-owning elements are not reparented.
- Voice-first rest is a single subtle hold-to-talk pill; text-first rest is a compact emphasized pill; any typed text, focus, staged command, or attachment enters the emphasized typing container.
- Text field max height is six lines; staged attachment thumbnails are 56pt and scroll horizontally. Treat these as existing composer geometry, not new system tokens.

## 5. Components

### Prego Theme Access

| Aspect | Contract |
|---|---|
| Structure | `PregoDesignSystem` is a `ThemeExtension` containing `colors`, `textTheme`, `spacing`, `radius`, `widths`, and `shadows`. |
| Usage | Product widgets read `context.prego`; `MaterialApp.router` wires `PregoColors`, `PregoTextTheme`, and `PregoDesignSystem` for light and dark themes. |
| Rule | Do not use `Theme.of(context).colorScheme` or `Theme.of(context).textTheme` where Prego has an equivalent token. |

### Prego Glass Scaffold And Top Navigation

| Aspect | Contract |
|---|---|
| Structure | `PregoGlassScaffold` owns page scroll, large-title collapse, refresh offset, optional banner height, and top-bar inset. `PregoTopNavigation` renders the transparent bar and title modes. |
| Variants | Collapsing large title, inline title, and back-leading title block. |
| States | The bar title fades in as the large title fades out; bodies that own scroll pass `reserveBarSpace: false` and manage top inset themselves. |
| Surface | The bar itself stays transparent; glass is reserved for icon buttons and scroll-edge fades. Android disables real glass effects and uses solid fallbacks. |

### Prego Solid Buttons And Tappable Interaction

| Aspect | Contract |
|---|---|
| Structure | `PregoButtonsSolid` composes `PregoTappable`, semantic button hierarchies, tokenized foreground/background/border, focus rings, and optional skeuomorphic overlay. |
| Variants | Hierarchy: `primary`, `primaryAlt`, `secondary`, `tertiary`, `link`; size: `sm`, `md`, `lg`, `xl`; tone: `regular`, `destructive`, `warning`, `success`; content: label or icon-only. |
| States | Enabled, hover, pressed, focus, disabled, and loading are cataloged in `client/design_catalog`; invalid tone/hierarchy pairs are blocked by assertions and catalog notices. |
| Rules | `primaryAlt` is regular only; warning/success are primary only; icon-only controls used in composer are 44pt via `lg`. |

### Composer Surfaces, Cards, And Picker Pills

| Aspect | Contract |
|---|---|
| Structure | `pregoComposerSurfaceDecoration` returns `bgSurface2`, full/custom radius, tokenized border, and `shadows.xs`. |
| Variants | `PregoComposerSurfaceStyle.subtle` uses `borderSecondary`; `emphasized` uses `borderPrimary`. |
| Components | `PregoCard`, `PregoPickerButton`, `BackgroundTasksBar`, and `PromptInput` use this shared decoration so adjacent surfaces move as one system. |
| Rules | Adjacent controls must follow the active `surfaceStyleController`; do not fork composer fill, border, or elevation for local states. |

### PromptInput Voice Composer

| Aspect | Contract |
|---|---|
| Structure | `PromptInput` owns the local Flutter surface, while parent cubits own persisted drafts, command staging, model/agent selections, and submission. |
| Layouts | `holdToTalk` is voice-first resting and subtle; `compact` is text-first resting and emphasized; `typing` is emphasized and contains the text field plus either a nested subtle hold pill or text-first action row. |
| Gesture ownership | Hold-to-record is handled by raw pointer `Listener` on the hold area or mic button; the gesture owner must stay mounted through recording so pointer-up can stop or cancel. |
| Voice state | Idle shows hint or field content; recording shows `PregoVoiceWaveform`; transcribing shows `PregoShimmer` over `Transcribing...`; layout is pinned during voice interaction. |
| Draft mutation | Typed edits call `onDraftChanged`; voice transcription calls `_applyDraft` only after `stopAndTranscribe()` returns a non-empty terminal transcript. |
| Rules | Do not move the waveform, cancel target, or mic into a different subtree mid-hold; do not raise the keyboard after a voice-first reviewed transcript unless the field was already focused. |

### Realtime Transcript Preview In PromptInput

| Aspect | Contract |
|---|---|
| Source | `VoiceTranscriptionService.currentPreview` and `previewStream` expose `confirmedText` and `provisionalText` during realtime recording. |
| Confirmed preview | Confirmed realtime transcript preview is primary/stable: append confirmed deltas in order, render them as reviewable composer content using `textPrimary`, and treat them as the only preview text eligible for terminal draft insertion. |
| Provisional preview | Provisional preview is secondary/replacement-only: render it after confirmed text with lower emphasis such as `textSecondary` or placeholder treatment, replace the full provisional segment on every event, and never append provisional text to itself. |
| Locality | Preview is interaction-local: it belongs to the active voice interaction, clears when realtime state resets, and must not persist in `ComposerDraft`, parent cubits, queued messages, or session transcript while recording/transcribing. |
| Mutation boundary | No draft mutation until terminal outcome: realtime preview must not write `_draft`, `TextEditingController`, or `onDraftChanged` while events are streaming. On terminal success, append only confirmed text through the existing voice-transcript draft path. A failed terminal outcome appends non-empty confirmed partial text through the same path, drops provisional text, clears preview, and shows the typed failure. Cancel commits nothing. |
| Placement | Keep preview inside the existing voice-aware composer slot or typing container chrome; it must not create a message bubble, background-task row, or persistent draft preview outside the composer. |

### Voice Waveform, Cancel Target, And Shimmer

| Aspect | Contract |
|---|---|
| Waveform | `PregoVoiceWaveform` paints 3px pill bars on a 6.5px grid at 24px height, driven by 100ms amplitude samples and a repaint ticker inside a `RepaintBoundary`. |
| Cancel target | `VoiceCancelButton` is a 44pt semantic button: dashed ghost at progress 0, solid `bgErrorSolid` disk and white icon at progress 1. |
| Drag wash | `PromptInput` paints a `bgDestructivePressedAlt` gradient behind pill content as cancel progress rises. |
| Shimmer | `PregoShimmer` sweeps a 1500ms sheen over decorative skeleton/text content, appears after 300ms by default, and can carry a replacement semantic label. |
| Rules | Waveform is decorative and excluded from semantics; recording semantics live on the hold/mic surface. Reduced motion snaps waveform slots and disables shimmer sweep without removing the static loading shape. |

### Message And List Surfaces

| Aspect | Contract |
|---|---|
| User message | `UserMessageBubble` is right-aligned, max 85% screen width, `bgBrandPrimary`, `PregoRadius.x2l`, and optional brand border for pending/outlined state. |
| Assistant message | Assistant parts are left-aligned in the transcript column and use part-specific widgets for text, reasoning, tool, subtask, agent, retry, and files. |
| Queued message | `QueuedMessageBubble` reuses `UserMessageBubble`, then adds a compact `textXs.medium` status line and optional 44pt cancel action. |
| Project/list rows | Rows use Prego text, `PregoSpacing.xl/lg` padding, bottom hairlines, skeleton geometry that matches real line boxes, and shimmer wrapped around whole loading regions. |

## 6. Motion & Interaction

### Timing

| Type | Duration | Easing | Existing Usage |
|---|---:|---|---|
| Composer morph | 220ms | `Curves.easeOutCubic` | Layout, padding, and state switch in `PromptInput` |
| Release hint swap | 150ms | AnimatedSwitcher default | `Release to transcribe` / `Release to cancel` |
| Options accordion | 200ms | `Curves.easeOutCubic` | Width expansion and chevron rotation |
| Queued bubble transition | 240ms | `Curves.easeInOutCubic` | Pending/sending bubble outline transition |
| Web tappable minimum feedback | 150ms | direct state | Pointer feedback on web/desktop |
| iOS tappable press | 300ms press, 150ms release | overshoot peak 1.25, scale settles at 1.09 | Physical button pulse and shadow interpolation |
| Shimmer sweep | 1500ms period | linear controller | Skeleton and transcribing text shimmer |
| Shimmer appear | 300ms delay, 200ms fade | opacity | Avoids flashes on fast loads |
| Waveform sample | 100ms sample interval | per-frame eased slide | Live recording waveform |
| Voice success haptic | 100ms gap | haptic sequence | light impact, then heavy impact after terminal transcript |

### Rules

- Motion must serve state: recording, cancellation, loading, selection, focus, route transition, or physical tap feedback.
- Preserve `PregoReducedMotionStateMixin` behavior: waveform still updates by sample, shimmer becomes static, and route/list transitions can become `Duration.zero` where existing code checks `context.isReducedMotion`.
- Do not add decorative motion to realtime preview. Confirmed/provisional transcript preview should update as text, not with a separate animated component outside the existing composer morph/shimmer grammar.
- Keep haptic ownership in voice interactions: touch-down acknowledges recording start, crossing the cancel threshold ticks selection feedback, terminal transcript gets success feedback, and cancel gets dismiss feedback.

## 7. Depth & Surface

### Strategy

Prego uses a mixed strategy: tonal surfaces for page hierarchy, solid pill/card surfaces for work controls, skeuomorphic overlays for solid buttons, and glass only where navigation chrome requires it.

| Level | Token/Primitive | Usage |
|---|---|---|
| Ambient | `bgSurface1` | Page and transcript background |
| Floating control | `bgSurface2` + subtle/emphasized border + `shadows.xs` | Composer, picker pills, `PregoCard`, background tasks |
| Local raised control | `bgSurface4` + `borderPrimary` | Options accordion, badges, small action circles |
| Solid action depth | `PregoSkeuomorphicOverlay` + focus/shadow tokens | Primary/secondary solid buttons and accordion surface |
| Glass navigation | `PregoButtonsIconGlass`, `GlassScaffold` edge fade | Top navigation buttons and scroll-edge atmosphere |
| Destructive voice state | `bgDestructivePressedAlt` gradient + `bgErrorSolid` cancel target | Drag-to-cancel affordance only |

### Rules

- Composer pills are solid on every platform; do not introduce liquid glass into the composer or preview surface.
- Android uses flat/solid fallbacks for glass because real glass effects can jank; do not force `liquid_glass_widgets` blur on Android.
- Surfaces should be clipped to their radius before painting content. `PregoCard` uses `ClipRRect` and transparent `Material`; buttons clip overlays inside the border.
- Do not add shadows directly unless a `PregoShadows` token already describes the elevation. Composer-like surfaces use `shadows.xs`.

## 8. Accessibility Constraints & Accepted Debt

### Constraints

- Target WCAG 2.2 AA: body/content contrast should meet 4.5:1, large/control text should meet 3:1, and focus state must be visible for every keyboard-reachable control.
- Interactive targets in the composer are 44pt or larger; if a visual icon is smaller, the semantic/tap target must remain 44pt.
- Voice recording must be operable without press-and-hold: semantic activation toggles record/stop because assistive technologies cannot express a held pointer gesture.
- Recording helper text is a live region; waveform and skeletons are decorative and excluded from semantics; `PregoShimmer.semanticLabel` replaces decorative loading children.
- Realtime preview should avoid noisy announcements for every provisional replacement. Stable confirmed preview may be announced as composer-local status; provisional preview should remain visually secondary and should not masquerade as committed draft text.
- Text scaling must expand rows instead of clipping. Existing list/status rows use minimum heights, flexible labels, ellipsis, and scrollable attachment strips to survive narrow screens and large text.
- Route/back behavior must dismiss the keyboard before popping on Android when the composer is focused; picker pills intentionally sit outside the `TextFieldTapRegion` so tapping them dismisses the keyboard for menu space.

### Accepted Debt

| Item | Location | Why accepted | Owner / Exit |
|---|---|---|---|
| Medium solid-button padding uses raw 14px/10px constants instead of spacing tokens. | `client/module_prego/lib/components/buttons/prego_buttons_solid.dart` | Figma specifies values between `PregoSpacing.lg/xl` and `md/lg`; preserving shipped button geometry matters more than forcing the scale. | Keep until Figma exports matching semantic tokens or button sizing is re-tokenized. |
| Voice composer gesture geometry uses local constants such as 44pt action size, 170pt cancel reach, and 56pt attachments. | `client/app/lib/features/session_detail/widgets/prompt_input.dart` and `voice_cancel_button.dart` | These constants are coupled to current Figma voice states and pointer physics; centralizing them now would risk behavior changes. | Extract only with a dedicated composer primitive pass and gesture QA. |
| Design catalog currently covers `PregoButtonsSolid` curated states, not the composer/waveform/realtime preview states. | `client/design_catalog` | Existing catalog guidance is in place, but production composer states are not yet represented as synthetic scenarios. | Add composer scenarios when realtime preview becomes a reusable or review-critical visual state. |
| Generated Prego token files are the source of many exact values. | `client/module_prego/lib/theme/primitives/*.g.dart` | They must not be edited by hand; token changes require Figma export and `sync_figma_tokens.dart`. | Update through the token sync pipeline only. |
