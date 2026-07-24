---
name: release-notes
description: Generate a polished, user-facing release-notes markdown file for a requested release (e.g. "do this for v1.1.0"). By default it starts from the existing auto-generated GitHub release notes and post-processes them (re-orders by importance, merges multi-PR efforts, highlights the big items, drops noise) while preserving the "All PRs merged" section verbatim. Alternatively, when the user explicitly says NOT to use the existing notes, it analyzes all commits/PRs merged since the previous release tag and builds the notes from scratch. Writes a RELEASE_NOTES_<version>.md file only — never edits the live GitHub release.
compatibility: opencode
metadata:
  audience: maintainers
  workflow: github
---

# Release Notes Skill

Generates a curated, user-facing release-notes markdown file for a given release version. The output mirrors the hand-edited style the maintainer prefers: a top **Highlights** block, then per-target **App** / **Bridge** sections (subdivided into New / Improved / Fixed / Other), then the original **All PRs merged** list kept verbatim.

This skill **only writes a file** (`RELEASE_NOTES_<version>.md` in the repo root). The maintainer manually pastes the result into the GitHub release once happy. **Never edit, publish, or otherwise mutate the live GitHub release.**

## Inputs

- **Version (required)** — e.g. `v1.1.0`. If the user omits the `v`, normalize to `v<x.y.z>`.
- **Highlight hints (optional)** — the user may volunteer domain knowledge inline, e.g. "the windows fix was fully broken before", "android login often failed". Treat these as authoritative and weave them into Highlights / phrasing.
- **Availability hints (optional)** — statements such as "this feature was hidden", "it was disabled before release", or "only OpenCode works in this release" are authoritative shipping decisions. Apply the rules below without asking the user to reconfirm them.
- **Mode override (optional)** — a phrase like "don't use the existing release notes", "build it from the commits", "analyze the PRs/commits since last release" switches to **Mode B** (commit analysis). Absent such a phrase, **always use Mode A** (existing GitHub release notes).

## Prerequisites

- `gh` CLI authenticated (`gh auth status`).
- For **Mode B** only: `dart` on PATH (to run `tool/generate_release_notes.dart`).
- Run from inside the repo (the worktree root is fine).

---

## Mode A — Start from existing GitHub release notes (DEFAULT)

Use this unless the user explicitly asked to ignore the existing notes.

### Step A1: Fetch the existing release

```bash
gh release view <version> --repo sesori-ai/sesori_apps_monorepo --json tagName,body,url
```

If the release is not found, list recent releases and ask the user which one they meant:

```bash
gh release list --repo sesori-ai/sesori_apps_monorepo --limit 15
```

The `body` field contains the auto-generated notes with `### App`, `### Bridge`, and `### All PRs merged` sections.

### Step A2: Parse the existing notes

From the fetched body, extract:
- Every App entry (Added / Fixed / Changed) with its PR number(s).
- Every Bridge entry with its PR number(s).
- The complete **All PRs merged** list (keep this text exactly as-is for the final output).

### Step A3: Apply the post-processing rules

Apply all rules in the **Post-Processing Rules** section below to the App and Bridge entries.

### Step A4: Write the file

Write `RELEASE_NOTES_<version>.md` using the **Output Format** below. The **All PRs merged** section is copied verbatim from the source.

---

## Mode B — Generate raw notes from commits/PRs, then post-process

Use this ONLY when the user explicitly says not to use the existing notes.

**Do NOT hand-roll the range resolution, PR enumeration, or App/Bridge classification in shell.** The repo already ships a deterministic, dependency-free generator — `tool/generate_release_notes.dart` — that CI uses for both the rolling internal pre-release and the production release. It already handles every tricky case correctly:

- **Previous-stable resolution** prefers the highest published (non-draft, non-prerelease) `vX.Y.Z` GitHub release strictly below the target (what users actually received), and only falls back to plain `vX.Y.Z` git tags — internal/prerelease tags like `v<X.Y.Z>-internal.<N>` are excluded.
- **PR enumeration** walks the full `compare` API (paged, no arbitrary cap) and refuses to emit truncated notes.
- **Exclusions**: drops `dependabot` / `dependabot[bot]` authors and any PR labelled `ignore-for-release`.
- **App/Bridge classification** pages `/pulls/<n>/files` fully and degrades conservatively (lists under both) when a PR is too large to enumerate.

Reusing it means Mode B and CI can never drift, so just run it instead of re-deriving the same data.

### Step B1: Generate the raw auto-notes with the canonical tool

```bash
# GITHUB_TOKEN/GH_TOKEN must be set (gh auth token works).
GITHUB_TOKEN="$(gh auth token)" dart tool/generate_release_notes.dart \
  --repo sesori-ai/sesori_apps_monorepo \
  --to <version> \
  --version <X.Y.Z> \
  --output /tmp/raw_release_notes_<version>.md
```

- `--to` is the tag/sha being released (e.g. `v1.1.0`); `--version` is the bare semver.
- **Omit `--from`** in normal use. The generator resolves the previous stable release itself: it prefers the highest *published* (non-draft, non-prerelease) `vX.Y.Z` release **strictly below the target**, and only falls back to plain `vX.Y.Z` git tags. Because it is strictly-below and published-release-aware, this is correct for both the latest release and older/backfill targets — do **not** compute a range by hand.
- **User-supplied range:** if the user explicitly gives a previous tag/ref, pass it as `--from` to override auto-resolution.
- The tool prints the resolved `from...to` range to stderr — always surface it to the user and confirm it looks right before proceeding.

This produces the same structure Mode A consumes: `### App`, `### Bridge`, and `### All PRs merged` (plus a `**Full Changelog**` link).

### Step B2: Parse, post-process, and write the file

From here the flow is identical to Mode A:

1. Parse the generated `### App`, `### Bridge`, and `### All PRs merged` sections (same as Step A2).
2. Apply the **Post-Processing Rules** to the App/Bridge entries (same as Step A3).
3. Write `RELEASE_NOTES_<version>.md` using the **Output Format**, copying the **All PRs merged** section verbatim from the generated output.

This guarantees Mode B's range, exclusions, and classification exactly match what GitHub would have shown — the only difference from Mode A is that the raw notes come from the generator instead of an already-published release.

---

## Post-Processing Rules (both modes)

Apply these to produce the App and Bridge narrative sections. The **All PRs merged** section is NEVER curated — it stays complete.

1. **Merge multi-PR efforts into one entry.** Collapse clusters that are obviously one initiative (e.g. titles like "migration PR 5/15", a series of "sesori_plugin_runtime — …" PRs, or a feature plus its follow-ups). Write a single descriptive bullet and append all the PR links: `([#223](…), [#226](…), …)`. Describe the *final shipped outcome*, not the mechanics of each PR.

2. **Drop chore/CI/infra/release-plumbing from the narrative.** Exclude version bumps, release commits, `ci:` workflow changes, linguist/gitattributes, editor configs, dependency-tooling wiring, and similar from the App/Bridge sections. They remain in **All PRs merged**. (Keep genuine user-relevant dependency/runtime bumps like a Flutter SDK upgrade under **Other**.)

3. **Collapse fixes to unreleased code automatically.** If a "fix" PR repairs a feature added in this same release, users never received the broken intermediate state. When the completed feature ships, fold the feature and its follow-up PRs into one **New** or **Improved** outcome and cite the combined PR set. Do not create a separate **Fixed** entry or say that Sesori fixed behavior users never saw. Ask the user only when inspection cannot establish whether the original behavior shipped in an earlier release.

4. **Treat hidden or disabled work as unavailable.** If the user says a feature was hidden, disabled, incomplete, or limited to one backend before release, omit that feature and its dependent fixes from Highlights and the normal New / Improved / Fixed narrative. Do this without another confirmation question. If the raw PR list could otherwise imply that the feature is available, add one restrained **Other** bullet stating the exact current availability limitation. Describe the broader work as preparatory only when the user says so or inspected evidence supports that characterization; keep it out of Highlights and never advertise it as usable.

5. **Reframe perf/UX wins out of "Fixed".** Items that aren't strictly bugs but improve feel (removing a UI-thread freeze via isolates, more natural scroll/collapse behavior, faster reconnect) belong in an **Improved** subsection with benefit-oriented wording, not **Fixed**.

6. **Order by real user impact.** Within each subsection, lead with the changes that matter most to users (reliability fixes, platform support, major UX) and push minor polish to the bottom. The **Highlights** block surfaces the few biggest items across both targets.

7. **Highlights block — the editorial layer.**
   - If the user provided highlight hints, treat them as authoritative: use their framing (severity, "was fully broken", "often failed", etc.).
   - Otherwise, infer the top items from PR titles + scope. Good highlight candidates: new platform support, reliability fixes for flows that affect everyone (login, reconnect), and large UX features (adaptive layout, etc.).
   - **When a PR's user benefit is unclear**, do one of: (a) inspect the implementation/diff to understand impact (`gh pr view <n> --json title,body` / `gh pr diff <n>`), or (b) ask the user a concise question about what it does and how important it is. Prefer inspecting first; ask when still ambiguous.
   - The bold lead must plainly name the important product change, such as "Redesigned sessions list" or "Improved Bridge onboarding." Do not replace the change with a vague slogan or inferred promise such as "Triage at a glance," "Stay connected," or "Make it yours."
   - Use the non-bold sentence to add concrete supporting detail: what changed in the UI or behavior, the most useful specifics, and why users will notice. The highlight should make sense without opening its PRs.
   - Keep Highlights to roughly 4–7 items, but do not promote a modest fix merely to fill the block. Four clear, release-defining changes are better than padded or speculative highlights. Each item may have a leading emoji to match house style.

8. **Voice.** User-facing, benefit-first, concrete. Avoid internal jargon and PR-mechanics. Don't invent capabilities not supported by the PRs.

---

## Output Format

Write to `RELEASE_NOTES_<version>.md` in the repo root:

```markdown
# <version> (build <N if known>)

## ✨ Highlights

- **<emoji> <Concrete product change>.** <Specific details about what changed and why users will notice.> ([#NNN](url), [#MMM](url))
- ... (4–7 items)

---

## 📱 App

**New**
- <entry> ([#NNN](url))

**Improved**
- <entry> ([#NNN](url))

**Fixed**
- <entry> ([#NNN](url))

**Other**
- <entry> ([#NNN](url))

---

## 🖥️ Bridge

**New**
- ...

**Improved**
- ...

**Fixed**
- ...

**Other**
- ...

---

## All PRs merged

<verbatim list from the GitHub release (Mode A) OR generated list (Mode B)>
```

Omit any subsection (New/Improved/Fixed/Other) that has no entries. If a target (App or Bridge) had no user-facing changes, write a single `- No user-facing changes` bullet under it.

---

## Workflow Summary

1. Determine **version** and **mode** (default = Mode A). Capture any highlight hints the user gave.
2. **Mode A:** `gh release view <version>` → parse App/Bridge/All-PRs. **Mode B:** run `dart tool/generate_release_notes.dart` (with `GITHUB_TOKEN`) to produce the raw App/Bridge/All-PRs notes, then parse them the same way as Mode A. Do not re-derive the range, exclusions, or classification by hand.
3. Apply the **Post-Processing Rules** (merge clusters into final outcomes, drop noise, collapse fixes to unreleased code, omit disabled work, reframe perf/UX, order by impact, build Highlights).
4. For unclear-benefit or unclear-shipping PRs, inspect the diff (`gh pr diff <n>`) before asking the user. Do not ask about clearly same-release repairs or availability decisions the user already supplied; apply the defaults above.
5. Write `RELEASE_NOTES_<version>.md`. Report the path and a short summary of editorial decisions made (what was merged, dropped, flagged).

## Important Notes

- This skill writes a **file only** — it never edits or publishes the GitHub release.
- Default behavior is **always Mode A** (start from existing GitHub release notes). Only switch to Mode B on an explicit instruction to ignore the existing notes.
- The **All PRs merged** section is never trimmed or curated.
- Confirm the resolved previous tag in Mode B. Surface an omission candidate only when shipping history remains ambiguous after inspection; collapse clear same-release repair clusters automatically.
- Repo is `sesori-ai/sesori_apps_monorepo`; requires authenticated `gh`.
