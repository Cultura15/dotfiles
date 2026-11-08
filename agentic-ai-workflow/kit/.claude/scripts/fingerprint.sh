#!/usr/bin/env bash
# Prints a 12-char content hash of the code that TEST and REVIEW check.
# Same file contents give the same hash, committed or not, so a commit does not
# make a QA report stale, but any code edit (e.g. a fix round) does.
# Inputs come from .claude/workflow/fingerprint.paths (git pathspecs, ! = exclude).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

paths_file=".claude/workflow/fingerprint.paths"
specs=()
if [ -f "$paths_file" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    case "$line" in
      ''|'#'*) continue ;;
      '!'*) specs+=(":(exclude)${line#!}") ;;
      *) specs+=("$line") ;;
    esac
  done < "$paths_file"
fi
[ ${#specs[@]} -eq 0 ] && specs=(. ':(exclude)docs' ':(exclude).claude')

tmp="${TMPDIR:-/tmp}/qa-fingerprint-files.$$"
trap 'rm -f "$tmp"' EXIT

git ls-files -co --exclude-standard -- "${specs[@]}" \
  | LC_ALL=C sort -u \
  | while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done \
  > "$tmp"

if [ ! -s "$tmp" ]; then
  echo "000000000000"
  exit 0
fi

paste -d' ' <(git hash-object --stdin-paths < "$tmp") "$tmp" \
  | git hash-object --stdin | cut -c1-12
