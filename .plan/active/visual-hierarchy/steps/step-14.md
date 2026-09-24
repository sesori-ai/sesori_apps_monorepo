# Step 14 — Needs-you card

## What changed

- `SessionDetailPendingBanner`, a brand or green glass tile floating over the
  transcript and wider than the column, becomes `SessionDetailNeedsYouCard`: a solid amber card (D6) docked
  above the composer, inside the same column as the composer and 16 points in
  from its edges, so the two line up.
- One card per request type, questions first. Each shows the existing count
  label ("1 pending question"), the first request's opening line, and an
  Answer or Review button that opens the existing modal.
- The cards join the floating bottom controls, so the transcript's bottom
  inset includes them and the newest message rests above the card.
- Card text and icon are dark (`gray950`) in both themes: white on the warning
  fill fails contrast (2.35:1 dark, 3.49:1 light).
- Read-only, archived and blocked sessions show no card, as before.

## Verification

- `client/module_app_ui`, `client/app` and `client/desktop`:
  `dart analyze --fatal-infos` is clean.
- `client/app` `test/features/session_detail` passes. A new test checks both
  cards, their order above the composer, the composer's width, the amber fill,
  and that Answer opens the question modal. Existing tests find the question
  inside `QuestionModal`, since the card now previews the same text.
- `client/desktop` `test/core` and `test/features` pass; the pending-question
  test opens the modal through Answer.
- Rendered the desktop session page with a pending question (light) and a
  pending permission (dark) and checked the card by eye.
