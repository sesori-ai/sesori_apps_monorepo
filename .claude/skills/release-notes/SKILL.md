---
name: release-notes
description: Generate polished, user-facing release notes in Markdown for a requested release (e.g. "do this for v1.1.0"). By default it starts from the existing auto-generated GitHub release notes and post-processes them (re-orders by importance, merges multi-PR efforts, highlights the big items, drops noise) and keeps the "New Contributors" section verbatim. Alternatively, when the user explicitly says NOT to use the existing notes, it analyzes all commits/PRs merged since the previous release tag and builds the notes from scratch. Writes the notes to a Markdown file in /tmp and returns a file reference — never writes into the repository and never edits the live GitHub release.
---

# release-notes (Claude Code shim)

Read `.agents/skills/release-notes/SKILL.md` now and follow it in full.
