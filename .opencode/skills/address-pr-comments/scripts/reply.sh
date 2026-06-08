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
    --repo) [[ $# -lt 2 ]] && { echo "Error: --repo requires a value" >&2; usage; exit 2; }; REPO="$2"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    --)           shift; break ;;
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

# Collect any remaining arguments after -- as part of the body
if [[ $# -gt 0 ]]; then
  if [[ -z "$BODY" ]]; then
    BODY="$*"
  else
    BODY="$BODY $*"
  fi
fi

if [[ -z "$PR_NUMBER" || -z "$COMMENT_ID" || -z "$BODY" ]]; then
  echo "Error: Missing required arguments" >&2
  usage; exit 2
fi

if [[ "$PR_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  :
else
  echo "Error: PR number must be a positive integer, got: $PR_NUMBER" >&2
  exit 2
fi

if [[ "$COMMENT_ID" =~ ^[1-9][0-9]*$ ]]; then
  :
else
  echo "Error: Comment ID must be a positive integer, got: $COMMENT_ID" >&2
  exit 2
fi

if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi

if [[ "$BODY" != "[Sesori reply]"* ]]; then
  BODY="[Sesori reply] $BODY"
fi

if ! gh api "repos/${REPO}/pulls/${PR_NUMBER}/comments/${COMMENT_ID}/replies" \
  -f body="$BODY" > /dev/null; then
  echo "Error: failed to post reply to comment ${COMMENT_ID} on PR #${PR_NUMBER} in ${REPO}" >&2
  exit 1
fi

echo "Reply posted to comment ${COMMENT_ID} on PR #${PR_NUMBER}"
