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

- **Previous-stable resolution** prefers the highest published (non-draft, non-prerelease) `vX.Y.Z` GitHub release (what users actually received), and only falls back to plain `vX.Y.Z` git tags — internal/prerelease tags like `v<X.Y.Z>-internal.<N>` are excluded.
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
- Omit `--from` to let the tool auto-resolve the previous stable release; pass `--from <tag>` only if the user explicitly gives a range.
- The tool prints the resolved `from...to` range to stderr — surface it to the user before proceeding.

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

1. **Merge multi-PR efforts into one entry.** Collapse clusters that are obviously one initiative (e.g. titles like "migration PR 5/15", a series of "sesori_plugin_runtime — …" PRs, or a feature plus its follow-ups). Write a single descriptive bullet and append all the PR links: `([#223](…), [#226](…), …)`. Describe the *outcome*, not the mechanics of each PR.

2. **Drop chore/CI/infra/release-plumbing from the narrative.** Exclude version bumps, release commits, `ci:` workflow changes, linguist/gitattributes, editor configs, dependency-tooling wiring, and similar from the App/Bridge sections. They remain in **All PRs merged**. (Keep genuine user-relevant dependency/runtime bumps like a Flutter SDK upgrade under **Other**.)

3. **Flag likely never-shipped bug fixes.** If a "fix" PR repairs a feature that was *added in this same release* (e.g. a split-view bug when split-view itself shipped this release, or a snackbar fix for a not-yet-released flow), it never reached production users and should usually be omitted. The skill cannot confirm prod state from git alone, so **list these as omission candidates and ask the user** unless they already told you. Default recommendation: omit.

4. **Reframe perf/UX wins out of "Fixed".** Items that aren't strictly bugs but improve feel (removing a UI-thread freeze via isolates, more natural scroll/collapse behavior, faster reconnect) belong in an **Improved** subsection with benefit-oriented wording, not **Fixed**.

5. **Order by real user impact.** Within each subsection, lead with the changes that matter most to users (reliability fixes, platform support, major UX) and push minor polish to the bottom. The **Highlights** block surfaces the few biggest items across both targets.

6. **Highlights block — the editorial layer.**
   - If the user provided highlight hints, treat them as authoritative: use their framing (severity, "was fully broken", "often failed", etc.).
   - Otherwise, infer the top items from PR titles + scope. Good highlight candidates: new platform support, reliability fixes for flows that affect everyone (login, reconnect), and large UX features (adaptive layout, etc.).
   - **When a PR's user benefit is unclear**, do one of: (a) inspect the implementation/diff to understand impact (`gh pr view <n> --json title,body` / `gh pr diff <n>`), or (b) ask the user a concise question about what it does and how important it is. Prefer inspecting first; ask when still ambiguous.
   - Keep Highlights to roughly 4–7 items. Each is one punchy sentence with the PR link(s), optionally a leading emoji to match house style.

7. **Voice.** User-facing, benefit-first, concrete. Avoid internal jargon and PR-mechanics. Don't invent capabilities not supported by the PRs.

---

## Output Format

Write to `RELEASE_NOTES_<version>.md` in the repo root:

```markdown
# <version> (build <N if known>)

## ✨ Highlights

- **<emoji> <Punchy benefit>.** <One-sentence explanation.> ([#NNN](url), [#MMM](url))
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
3. Apply the **Post-Processing Rules** (merge clusters, drop noise, flag never-shipped fixes, reframe perf/UX, order by impact, build Highlights).
4. For unclear-benefit PRs: inspect the diff (`gh pr diff <n>`) or ask the user. For likely never-shipped fixes: present as omission candidates (default omit) unless the user already decided.
5. Write `RELEASE_NOTES_<version>.md`. Report the path and a short summary of editorial decisions made (what was merged, dropped, flagged).

## Important Notes

- This skill writes a **file only** — it never edits or publishes the GitHub release.
- Default behavior is **always Mode A** (start from existing GitHub release notes). Only switch to Mode B on an explicit instruction to ignore the existing notes.
- The **All PRs merged** section is never trimmed or curated.
- Confirm the resolved previous tag (Mode B) and surface omission candidates before finalizing, so the maintainer stays in control of the editorial calls.
- Repo is `sesori-ai/sesori_apps_monorepo`; requires authenticated `gh`.
