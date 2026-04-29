#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: fetch.sh <pr-number> [--since ISO_DATETIME] [--unresolved] [--repo OWNER/REPO]

Fetches inline (code) review comments on a GitHub pull request, grouped
into threads, with optional filtering.

Flags:
  --since ISO_DATETIME   Keep only threads whose latest comment is at or
                         after the given datetime. ISO 8601 with timezone
                         is required (e.g. 2026-04-29T14:30:00Z or
                         2026-04-29T17:00:00+03:00). The script normalizes
                         to UTC internally.
  --unresolved           Keep only threads that are not yet resolved.
  --repo OWNER/REPO      Override the current repo.

Output is a single JSON array of thread objects on stdout. Each thread
includes is_resolved and is_outdated.
EOF
}

# -------- datetime validation + normalization --------

validate_iso8601() {
  local s="$1"
  local re='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:?[0-9]{2})$'
  [[ "$s" =~ $re ]]
}

# Normalize an ISO 8601 datetime to UTC with trailing Z. Handles GNU date
# (Linux) and BSD date (macOS) by feature detection. Echoes the normalized
# value on stdout, or an error to stderr and returns 1.
normalize_to_utc_z() {
  local input="$1"

  if ! validate_iso8601 "$input"; then
    cat >&2 <<EOF
Error: --since is not a valid ISO 8601 datetime with timezone.
  got:      ${input}
  expected: e.g. 2026-04-29T14:30:00Z or 2026-04-29T17:00:00+03:00
EOF
    return 1
  fi

  local stripped
  stripped=$(printf '%s' "$input" | sed -E 's/\.[0-9]+(Z|[+-])/\1/')

  local result
  if date --version >/dev/null 2>&1; then
    # GNU date (Linux). Forgiving: accepts Z, ±HH:MM, ±HHMM.
    if ! result=$(date -u -d "$stripped" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null); then
      echo "Error: --since looked valid but GNU date could not parse it: $stripped" >&2
      return 1
    fi
  else
    # BSD date (macOS). Strict: needs ±HHMM with no colon, rejects Z.
    local bsd_in
    bsd_in=$(printf '%s' "$stripped" \
      | sed -E 's/Z$/+0000/; s/([+-][0-9]{2}):([0-9]{2})$/\1\2/')
    if ! result=$(date -u -j -f "%Y-%m-%dT%H:%M:%S%z" "$bsd_in" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null); then
      echo "Error: --since looked valid but BSD date could not parse it: $bsd_in" >&2
      return 1
    fi
  fi

  printf '%s\n' "$result"
}

# -------- argument parsing --------

PR_NUMBER=""
SINCE=""
REPO=""
ONLY_UNRESOLVED=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)      SINCE="${2:?--since requires a value}"; shift 2 ;;
    --repo)       REPO="${2:?--repo requires a value}";   shift 2 ;;
    --unresolved) ONLY_UNRESOLVED=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    -*)           echo "Unknown flag: $1" >&2; usage; exit 2 ;;
    *)
      if [[ -z "$PR_NUMBER" ]]; then
        PR_NUMBER="$1"
      else
        echo "Unexpected positional argument: $1" >&2
        usage; exit 2
      fi
      shift
      ;;
  esac
done

if [[ -z "$PR_NUMBER" ]]; then
  usage; exit 2
fi

if [[ -n "$SINCE" ]]; then
  ORIGINAL_SINCE="$SINCE"
  SINCE=$(normalize_to_utc_z "$SINCE") || exit 1
  if [[ "$SINCE" != "$ORIGINAL_SINCE" ]]; then
    echo "Normalized --since: ${ORIGINAL_SINCE} -> ${SINCE}" >&2
  fi
fi

if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
fi

OWNER="${REPO%%/*}"
REPO_NAME="${REPO##*/}"

# -------- fetch + transform --------

# GraphQL query. reviewThreads gives native threading + isResolved/isOutdated,
# which the REST /pulls/{n}/comments endpoint does not expose.
#
# Pagination: gh api graphql --paginate uses pageInfo.{hasNextPage,endCursor}
# and re-runs with $endCursor automatically. Inner comments are capped at
# 100 per thread; we warn if that cap is hit (extremely rare).
read -r -d '' GRAPHQL_QUERY <<'GQL' || true
query($owner: String!, $repo: String!, $pr: Int!, $endCursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100, after: $endCursor) {
        nodes {
          isResolved
          isOutdated
          path
          line
          originalLine
          startLine
          diffSide
          comments(first: 100) {
            nodes {
              databaseId
              author { login }
              body
              createdAt
              updatedAt
              url
              diffHunk
              commit { oid }
            }
            pageInfo { hasNextPage }
          }
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
}
GQL

gh api graphql --paginate \
  -F owner="$OWNER" \
  -F repo="$REPO_NAME" \
  -F pr="$PR_NUMBER" \
  -f query="$GRAPHQL_QUERY" \
| jq --slurp \
     --arg since "$SINCE" \
     --argjson onlyUnresolved "$ONLY_UNRESOLVED" '
    # Flatten all pages into a single list of thread nodes.
    [.[] | .data.repository.pullRequest.reviewThreads.nodes[]] as $threads

    # Surface a warning if any thread truncated its inner comments.
    | ($threads | map(select(.comments.pageInfo.hasNextPage)) | length) as $truncated
    | (if $truncated > 0 then
        ("warning: \($truncated) thread(s) had > 100 comments; output is truncated" | debug)
       else . end) as $_

    | $threads
    | map(
        # Skip empty threads defensively (should not happen).
        select(.comments.nodes | length > 0)
        | (.comments.nodes | sort_by(.createdAt)) as $sorted
        | $sorted[0] as $root
        | {
            # Thread-level fields, present once per thread.
            thread_id:   $root.databaseId,
            path:        .path,
            line:        (.line // .originalLine),
            side:        .diffSide,
            start_line:  .startLine,
            is_resolved: .isResolved,
            is_outdated: .isOutdated,
            commit_id:   ($root.commit.oid // null),
            diff_hunk:   $root.diffHunk,
            url:         $root.url,
            latest_at:   ($sorted | map(.createdAt) | max),

            # Per-comment fields only.
            comments: ($sorted | map({
              id:         .databaseId,
              user:       (.author.login // "ghost"),
              body,
              created_at: .createdAt,
              updated_at: .updatedAt,
              html_url:   .url
            }))
          }
      )
    | if $onlyUnresolved == 1 then map(select(.is_resolved == false)) else . end
    | if $since != ""           then map(select(.latest_at >= $since)) else . end
    | sort_by([.path // "", (.line // 0), .thread_id])
'
