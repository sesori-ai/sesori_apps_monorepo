#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: fetch.sh <pr-number> [--since ISO_DATETIME] [--repo OWNER/REPO]

Fetches inline (code) review comments on a GitHub pull request, groups
them into threads, and optionally filters to threads whose latest comment
is at or after ISO_DATETIME.

ISO_DATETIME must be ISO 8601 / RFC 3339 with an explicit timezone:
  2026-04-29T14:30:00Z
  2026-04-29T17:00:00+03:00
  2026-04-29T17:00:00+0300
  2026-04-29T14:30:00.123Z      (fractional seconds are accepted and stripped)

Datetimes without a timezone are rejected. Any input is normalized to
UTC Z form before use.

Output is a single JSON array of thread objects on stdout.
EOF
}

# -------- datetime validation + normalization --------

# Validate against a strict ISO 8601 grammar with required timezone.
# Returns 0 if valid, 1 otherwise.
validate_iso8601() {
  local s="$1"
  local re='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:?[0-9]{2})$'
  [[ "$s" =~ $re ]]
}

# Normalize an ISO 8601 datetime to UTC with trailing Z.
# Handles GNU date (Linux) and BSD date (macOS) by feature detection.
# Echoes the normalized value on stdout, or an error to stderr and returns 1.
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

  # Strip fractional seconds. GitHub never emits them and BSD date's %S
  # does not accept them. The validator already confirmed the structure.
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
    # BSD date (macOS). Strict: needs ±HHMM with no colon, and rejects Z.
    # Rewrite Z -> +0000 and ±HH:MM -> ±HHMM.
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since) SINCE="${2:?--since requires a value}"; shift 2 ;;
    --repo)  REPO="${2:?--repo requires a value}";   shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown flag: $1" >&2; usage; exit 2 ;;
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

# -------- fetch + transform --------

# gh api --paginate may emit either one merged array or multiple
# concatenated arrays depending on version. --slurp + add handles both:
# single array  -> [[...]]      -> add -> [...]
# multiple      -> [[..],[..]]  -> add -> [...]
gh api --paginate \
  -H "Accept: application/vnd.github+json" \
  "/repos/${REPO}/pulls/${PR_NUMBER}/comments" \
| jq --slurp --arg since "$SINCE" '
    # Walk in_reply_to_id chain back to the thread root.
    # Falls through to self.id if a parent is missing (orphaned reply).
    def root_id_of(c; $by_id):
      if c.in_reply_to_id == null then c.id
      else
        ($by_id[(c.in_reply_to_id|tostring)]) as $p
        | if $p == null then c.id else root_id_of($p; $by_id) end
      end;

    # Merge all pages into a flat list of comments.
    add as $all

    # Build id -> comment lookup table for the chain walk.
    | (reduce $all[] as $c ({}; .[($c.id|tostring)] = $c)) as $by_id

    # Tag each comment with its thread root id, group, and shape output.
    | $all
    | map(. + {_root: root_id_of(.; $by_id)})
    | group_by(._root)
    | map(
        .[0]._root as $rid
        # Pick the actual root comment for thread-level fields.
        # Fallback to first in group if root is missing (defensive).
        | ((map(select(.id == $rid))[0]) // .[0]) as $root
        | (sort_by(.created_at)) as $sorted
        | {
            # Thread-level fields: present once per thread.
            thread_id:  $root.id,
            path:       $root.path,
            line:       ($root.line // $root.original_line),
            side:       $root.side,
            start_line: $root.start_line,
            commit_id:  $root.commit_id,
            diff_hunk:  $root.diff_hunk,
            url:        $root.html_url,
            latest_at:  ($sorted | map(.created_at) | max),

            # Per-comment fields: only what differs between comments.
            comments: ($sorted | map({
              id,
              user:       .user.login,
              body,
              created_at,
              updated_at,
              html_url
            }))
          }
      )
    | if $since != "" then map(select(.latest_at >= $since)) else . end
    | sort_by([.path // "", (.line // 0), .thread_id])
'
