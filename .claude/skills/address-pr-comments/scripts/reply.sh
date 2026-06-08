#!/usr/bin/env bash
# Thin wrapper around the shared OpenCode reply.sh. The real logic (arg parsing,
# [Sesori reply] prefixing, gh API call) lives there, so it stays a single
# source of truth across harnesses. All arguments are forwarded verbatim.
set -euo pipefail
exec "$(git rev-parse --show-toplevel)/.opencode/skills/address-pr-comments/scripts/reply.sh" "$@"
