#!/usr/bin/env bash
# Start a workflow agent in a terminal from the repo root.
#   bash .claude/scripts/agent.sh review            # REVIEW, terminal 2
#   bash .claude/scripts/agent.sh git               # GIT, terminal 3
#   bash .claude/scripts/agent.sh test              # TEST in a terminal (uses Claude in Chrome)
# Optional second arg overrides the model, e.g. `agent.sh review claude-opus-5-5`.
set -euo pipefail
cd "$(dirname "$0")/../.."

role="${1:-}"
model="${2:-claude-sonnet-5-5}"

case "$role" in
  review) exec claude --model "$model" --settings .claude/permissions/review.json --append-system-prompt-file .claude/roles/review.md ;;
  git)    exec claude --model "$model" --setting-sources user,project --settings .claude/permissions/git.json --append-system-prompt-file .claude/roles/git.md ;;
  test)   exec claude --model "$model" --chrome --settings .claude/permissions/test.json --append-system-prompt-file .claude/roles/test.md ;;
  *) echo "usage: $0 review|git|test [model]" >&2; exit 1 ;;
esac
