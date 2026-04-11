#!/usr/bin/env bash
# Usage: helm-template-overlays.sh <chart-under-repo-root> [branch]
# Example: helm-template-overlays.sh gitops/helm/chat-app
# With branch: only that overlay (CI after image bump).
set -euo pipefail
REL="${1:?chart path under repo root}"
BRANCH_ARG="${2:-}"
ROOT="${GITHUB_WORKSPACE:-}"
[ -n "$ROOT" ] || ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$ROOT" ] || ROOT="."
CHART="$ROOT/$REL"
[ -d "$CHART" ] || { echo "::error::Missing chart dir $CHART" >&2; exit 1; }

if [ -n "$BRANCH_ARG" ]; then
  f="$CHART/values-${BRANCH_ARG}.yaml"
  [ -f "$f" ] || { echo "::error::Missing $f" >&2; exit 1; }
  helm template "chat-app-${BRANCH_ARG}" "$CHART" -f "$CHART/values.yaml" -f "$f"
  exit 0
fi

shopt -s nullglob
for f in "$CHART"/values-*.yaml; do
  case "$(basename "$f")" in values.yaml) continue ;; esac
  e="${f#"$CHART"/values-}"
  e="${e%.yaml}"
  helm template "chat-app-$e" "$CHART" -f "$CHART/values.yaml" -f "$f"
done
