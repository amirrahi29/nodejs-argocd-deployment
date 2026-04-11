#!/usr/bin/env bash
# Fetch, rebase onto remote (linear history), then push — avoids "rejected / fetch first"
# Usage: ./scripts/git-push.sh [branch]   (default: current branch)
set -euo pipefail
remote="${GIT_REMOTE:-origin}"
branch="${1:-$(git branch --show-current)}"
if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
  echo "error: not on a branch; pass branch name: $0 <branch>" >&2
  exit 1
fi
git fetch "$remote"
git pull --rebase "$remote" "$branch"
git push "$remote" "$branch"
