# PREGO Inspector Tracker

| Step | Status | Evidence |
|---|---|---|
| Capture approved plan and delivery boundary | Complete | `PLAN.md` |
| Implement inspector interaction and UI | Complete | `483e4528` |
| Implement PREGO token matching and tests | Complete | `483e4528` |
| Reconcile design-catalog regression documentation | Complete | `README.md`, `docs/regression/design-catalog.md` |
| Run L2 matrix and retire plan | Complete | L2 evidence below; plan retired after all required coverage passed |

## L2 Routine Evidence

- Automated: `flutter analyze`, focused inspector tests, the full 31-test
  design-catalog suite, manifest parity, inspector-token parity, and
  `flutter build web --release` all passed.
- Dark, text scale 1.0, iPhone 16 Pro Max: hover bounds aligned with the
  transformed text; the summary reported `14 px · text-sm / bold`; pinning,
  `]` target cycling (`1/16` to `2/16`), Escape clearing, and the adaptive
  details panel all worked without replacing or crashing the preview.
- Light, text scale 2.0, iPhone SE: the enlarged `246.4 × 40` heading bounds
  aligned exactly and the hover summary remained outside the selected text.
- Dark, text scale 1.0, Google Pixel 10 Pro: hover inspection aligned and
  reported `16 px · text-md / bold` for the button label.
- Inspector disabled: clicking the enabled catalog button left the normal
  preview intact and produced no inspector overlay or selection.
- Token honesty: the equal-valued `bg-secondary-alt` / `bg-surface1` fill
  exposed both candidates and no arbitrary Copy action.
- Release-web Copy: the unique typography action changed from `Copy bold` to
  `Copied`, retained the pinned Text target, and placed
  `context.prego.textTheme.textSm.bold` on the clipboard.
- Browser verification used a fresh local port for the rebuilt release output
  so cached debug assets could not satisfy the release check.
- Delivery remains local on `codex/design-catalog-audit-addons` until the open
  predecessor PR #906 merges.
