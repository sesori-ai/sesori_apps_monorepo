#!/usr/bin/env bash
#
# rename_zyra_to_prego.sh
#
# One-shot migration: rename the "Zyra" theme to "Prego" everywhere.
#   - replaces `zyra` -> `prego` and `Zyra` -> `Prego` in file CONTENTS
#   - renames any tracked FILE or DIRECTORY whose path contains zyra/Zyra
#
# Only tracked files (`git ls-files`) are touched, so:
#   - binary files are skipped for content edits (git grep -I), and
#   - sibling git worktrees under .worktrees/ are never affected.
#
# Idempotent-ish: safe to inspect with `git status` after running.
# Run from the repo root.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Substitution applied to both file contents and path names.
# Order is irrelevant: the two patterns are case-sensitive and disjoint.
subst() { sed -e 's/zyra/prego/g' -e 's/Zyra/Prego/g'; }

echo "==> 1/2  Rewriting file contents"
# -l: names only, -I: skip binary files, -z: NUL-delimited (safe for any path).
# Match either case variant; the sed handles both.
count=0
while IFS= read -r -d '' file; do
  LC_ALL=C sed -i '' -e 's/zyra/prego/g' -e 's/Zyra/Prego/g' "$file"
  count=$((count + 1))
done < <(git grep -lIz -e zyra -e Zyra)
echo "    rewrote $count file(s)"

echo "==> 2/2  Renaming paths (files + directories)"
# Rename leaf files to their fully-transformed path; parent directories
# (module_zyra/, SatoshiZyra/, ...) are recreated implicitly and the now-empty
# old directories disappear since git does not track directories.
# Sort by descending depth so nested paths move before their ancestors.
renamed=0
while IFS= read -r -d '' old; do
  new="$(printf '%s' "$old" | subst)"
  [ "$old" = "$new" ] && continue
  mkdir -p "$(dirname "$new")"
  git mv -- "$old" "$new"
  renamed=$((renamed + 1))
done < <(git ls-files -z | grep -zE '[Zz]yra' | tr '\0' '\n' | awk '{print gsub(/\//,"/")"\t"$0}' | sort -rn | cut -f2- | tr '\n' '\0')
echo "    renamed $renamed path(s)"

echo "==> Done. Review with: git status && git diff --cached --stat"
