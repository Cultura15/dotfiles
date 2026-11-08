#!/usr/bin/env bash
# Install the AI workflow kit into a project.
#   bash install.sh <path-to-project>          # copy, never overwrite existing files
#   bash install.sh <path-to-project> --force  # also overwrite generic files (commands, roles, scripts, templates)
# Project-specific files (.claude/workflow/PROJECT.md, fingerprint.paths, lint-on-save.json,
# .claude/launch.json, .claude/settings.json, permissions) are never overwritten, even with --force.
set -euo pipefail

kit="$(cd "$(dirname "$0")/kit" && pwd)"
target="${1:-}"
force="${2:-}"

if [ -z "$target" ] || [ ! -d "$target" ]; then
  echo "usage: bash install.sh <path-to-project> [--force]" >&2
  exit 1
fi
target="$(cd "$target" && pwd)"

if ! git -C "$target" rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "warning: $target is not a git repo. The fingerprint and GIT agent need git (run: git init)." >&2
fi

keep_always=(
  ".claude/workflow/PROJECT.md"
  ".claude/workflow/fingerprint.paths"
  ".claude/workflow/lint-on-save.json"
  ".claude/launch.json"
  ".claude/settings.json"
  ".claude/permissions/build.json"
  ".claude/permissions/test.json"
  ".claude/permissions/review.json"
  ".claude/permissions/git.json"
)

is_kept() {
  local f="$1" k
  for k in "${keep_always[@]}"; do [ "$f" = "$k" ] && return 0; done
  return 1
}

added=0; skipped=0; replaced=0
while IFS= read -r -d '' src; do
  rel="${src#"$kit"/}"
  dest="$target/$rel"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ]; then
    if [ "$force" = "--force" ] && ! is_kept "$rel"; then
      cp "$src" "$dest"; echo "  replaced  $rel"; replaced=$((replaced + 1))
    else
      echo "  kept      $rel (exists)"; skipped=$((skipped + 1))
    fi
  else
    cp "$src" "$dest"; echo "  added     $rel"; added=$((added + 1))
  fi
done < <(find "$kit" -type f -print0 | sort -z)

chmod +x "$target/.claude/scripts/"*.sh 2>/dev/null || true

# Personal settings mirror for BUILD, git-ignored.
if [ ! -e "$target/.claude/settings.local.json" ]; then
  cp "$target/.claude/permissions/build.json" "$target/.claude/settings.local.json"
  echo "  added     .claude/settings.local.json (copy of permissions/build.json)"
fi
gi="$target/.gitignore"
if ! grep -qxF ".claude/settings.local.json" "$gi" 2>/dev/null; then
  printf '\n# Claude Code: personal settings mirror\n.claude/settings.local.json\n' >> "$gi"
  echo "  updated   .gitignore (+ .claude/settings.local.json)"
fi

echo
echo "Done: $added added, $replaced replaced, $skipped kept."
echo "Next: open $target in the Claude desktop app and run /build:setup"
