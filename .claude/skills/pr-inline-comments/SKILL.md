---
name: pr-inline-comments
description: Fetch inline (code) review comments on a GitHub pull request, grouped into threads, with optional filtering by datetime. Use when the user asks to read or address PR comments, code review feedback, reviewer notes, or wants to see only recent review activity on a PR. Resolves natural-language time windows like "last 30 minutes", "since yesterday 5 PM", or "since commit abc123" into ISO 8601 before invoking the script. Should be invoked as a sub-agent so the large JSON result stays out of the main agent context, run with a low-intelligence model when one is available, since the work is mechanical. Requires gh and jq.
---

# pr-inline-comments (Claude Code shim)

Read `.agents/skills/pr-inline-comments/SKILL.md` now and follow it in full.
