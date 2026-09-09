#!/usr/bin/env bash
# Run after a full checkout (including tags), inside release-all's concurrency
# group. Only this workflow's main runs own the rolling attempt marker.
set -euo pipefail

ATTEMPT_TAG="internal-release-attempt"

skip_release() {
  echo "should_release=false" >> "$GITHUB_OUTPUT"
  echo "Skipping internal release: $1"
  echo "## Internal release skipped" >> "$GITHUB_STEP_SUMMARY"
  echo "$1" >> "$GITHUB_STEP_SUMMARY"
  exit 0
}

if [[ "$GITHUB_EVENT_NAME" == "schedule" ]]; then
  RELEASE_TAGS=$(git tag --points-at "$GITHUB_SHA" --list 'v[0-9]*')
  if [[ -n "$RELEASE_TAGS" ]]; then
    skip_release "Commit ${GITHUB_SHA} already has a release tag: ${RELEASE_TAGS//$'\n'/, }."
  fi

  BASELINE=$(git for-each-ref --format='%(objectname)' "refs/tags/${ATTEMPT_TAG}")
  if [[ "$BASELINE" == "$GITHUB_SHA" ]]; then
    skip_release "Commit ${GITHUB_SHA} was already attempted. Use Run workflow to retry manually."
  fi

  if [[ -z "$BASELINE" ]]; then
    # Bootstrap from the nearest release on this history. --always returns an
    # abbreviated SHA (not v*) when no release exists yet; that first run builds.
    BASELINE=$(git describe --tags --match 'v[0-9]*' --abbrev=0 --always "$GITHUB_SHA")
    if [[ "$BASELINE" != v* ]]; then
      BASELINE=""
    fi
  fi

  if [[ -n "$BASELINE" ]]; then
    # Preserve mobile-product scoping: desktop-only and unrelated documentation
    # changes must not spend a store upload. Compare the whole batch, not only the tip.
    # Release automation fixes also qualify, so a fixed pipeline can try again.
    if git diff --quiet "$BASELINE" "$GITHUB_SHA" -- \
      client/app/ client/module_core/ client/module_auth/ client/module_prego/ client/module_app_ui/ \
      client/pubspec.yaml client/pubspec.lock client/analysis_options.yaml client/Makefile \
      shared/ bridge/ .tool-versions tool/generate_release_notes.dart \
      .github/scripts/check_internal_release.sh .github/workflows/release-all-platforms.yml \
      '.github/workflows/_reusable-*.yml'; then
      skip_release "No release-relevant changes since ${BASELINE}."
    else
      STATUS=$?
      if [[ "$STATUS" -ne 1 ]]; then
        echo "::error::Could not compare release changes (git diff exited ${STATUS})." >&2
        exit "$STATUS"
      fi
    fi
  fi
fi

# Write BEFORE version checks, store queries or builds: failure/cancellation
# needs no cleanup job, and inability to persist the marker prevents uploads.
# Manual branch builds stay supported but cannot overwrite main's checkpoint.
if [[ "$GITHUB_REF" == "refs/heads/main" ]]; then
  git push --force origin "${GITHUB_SHA}:refs/tags/${ATTEMPT_TAG}"
fi

echo "should_release=true" >> "$GITHUB_OUTPUT"
{
  echo "## Internal release attempt"
  echo "Building commit ${GITHUB_SHA}. Manual runs bypass the scheduled skip checks."
} >> "$GITHUB_STEP_SUMMARY"
