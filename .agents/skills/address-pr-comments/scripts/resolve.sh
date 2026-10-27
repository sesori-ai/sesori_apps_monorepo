#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: resolve.sh <pr-number> <comment-id> [--repo OWNER/REPO]

Resolves the PR review thread containing the given comment via the GitHub
GraphQL API (thread resolution is not exposed over REST). Idempotent: an
already-resolved thread is reported and exits 0.

Arguments:
  pr-number    The pull request number
  comment-id   A comment ID belonging to the thread (thread_id from fetch.sh)

Flags:
  --repo OWNER/REPO  Override the current repo. Defaults to gh repo view.

Examples:
  resolve.sh 42 12345
  resolve.sh 42 12345 --repo owner/repo
EOF
}

PR_NUMBER=""
COMMENT_ID=""
REPO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) [[ $# -lt 2 ]] && { echo "Error: --repo requires a value" >&2; usage; exit 2; }; REPO="$2"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    -*)           echo "Unknown flag: $1" >&2; usage; exit 2 ;;
    *)
      if [[ -z "$PR_NUMBER" ]]; then
        PR_NUMBER="$1"
      elif [[ -z "$COMMENT_ID" ]]; then
        COMMENT_ID="$1"
      else
        echo "Unexpected positional argument: $1" >&2
        usage; exit 2
      fi
      shift
      ;;
  esac
done

if [[ -z "$PR_NUMBER" || -z "$COMMENT_ID" ]]; then
  echo "Error: Missing required arguments" >&2
  usage; exit 2
fi

if ! [[ "$PR_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: PR number must be a positive integer, got: $PR_NUMBER" >&2
  exit 2
fi

if ! [[ "$COMMENT_ID" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: Comment ID must be a positive integer, got: $COMMENT_ID" >&2
  exit 2
fi

if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi
OWNER="${REPO%%/*}"
NAME="${REPO##*/}"

# Find the GraphQL thread node containing the comment. fetch.sh reports the
# root comment's numeric (database) id as thread_id, so match any comment in
# each thread against it. --paginate walks PRs with >100 threads.
THREAD_JSON="$(gh api graphql --paginate \
  -f owner="$OWNER" -f name="$NAME" -F pr="$PR_NUMBER" \
  -f query='
    query($owner: String!, $name: String!, $pr: Int!, $endCursor: String) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $pr) {
          reviewThreads(first: 100, after: $endCursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              isResolved
              comments(first: 100) { nodes { databaseId } }
            }
          }
        }
      }
    }' \
  --jq ".data.repository.pullRequest.reviewThreads.nodes[]
        | select(.comments.nodes[].databaseId == ${COMMENT_ID})" | head -n 1)"

if [[ -z "$THREAD_JSON" ]]; then
  echo "Error: no review thread containing comment ${COMMENT_ID} found on PR #${PR_NUMBER} in ${REPO}" >&2
  exit 1
fi

THREAD_ID="$(jq -r '.id' <<<"$THREAD_JSON")"
IS_RESOLVED="$(jq -r '.isResolved' <<<"$THREAD_JSON")"

if [[ "$IS_RESOLVED" == "true" ]]; then
  echo "Thread for comment ${COMMENT_ID} on PR #${PR_NUMBER} is already resolved"
  exit 0
fi

if ! gh api graphql \
  -f threadId="$THREAD_ID" \
  -f query='
    mutation($threadId: ID!) {
      resolveReviewThread(input: { threadId: $threadId }) {
        thread { id isResolved }
      }
    }' > /dev/null; then
  echo "Error: failed to resolve thread for comment ${COMMENT_ID} on PR #${PR_NUMBER} in ${REPO}" >&2
  exit 1
fi

echo "Resolved thread for comment ${COMMENT_ID} on PR #${PR_NUMBER}"
