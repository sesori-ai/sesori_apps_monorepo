#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: reply.sh <pr-number> <comment-id> <body> [--repo OWNER/REPO]

Posts a reply to a PR review comment thread via the GitHub API.

Arguments:
  pr-number    The pull request number
  comment-id   The comment ID (thread_id from fetch.sh output)
  body         The reply body text. Will be prefixed with [Sesori reply] if not already.

Flags:
  --repo OWNER/REPO  Override the current repo. Defaults to gh repo view.

Examples:
  reply.sh 42 12345 "Addressed: Fixed the null check."
  reply.sh 42 12345 "Not addressed: This would break existing tests." --repo owner/repo
EOF
}

PR_NUMBER=""
COMMENT_ID=""
BODY=""
REPO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)       REPO="${2:?--repo requires a value}";   shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    -*)           echo "Unknown flag: $1" >&2; usage; exit 2 ;;
    *)
      if [[ -z "$PR_NUMBER" ]]; then
        PR_NUMBER="$1"
      elif [[ -z "$COMMENT_ID" ]]; then
        COMMENT_ID="$1"
      elif [[ -z "$BODY" ]]; then
        BODY="$1"
      else
        echo "Unexpected positional argument: $1" >&2
        usage; exit 2
      fi
      shift
      ;;
  esac
done

if [[ -z "$PR_NUMBER" || -z "$COMMENT_ID" || -z "$BODY" ]]; then
  echo "Error: Missing required arguments" >&2
  usage; exit 2
fi

if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi

OWNER="${REPO%%/*}"
REPO_NAME="${REPO##*/}"

if [[ "$BODY" != "[Sesori reply]"* ]]; then
  BODY="[Sesori reply] $BODY"
fi

gh api "repos/${OWNER}/${REPO_NAME}/pulls/${PR_NUMBER}/comments/${COMMENT_ID}/replies" \
  -f body="$BODY" > /dev/null

echo "Reply posted to comment ${COMMENT_ID} on PR #${PR_NUMBER}"
