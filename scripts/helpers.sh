#!/usr/bin/env bash
set -euo pipefail
usage() { echo "usage: $0 push [branch] | argocd-wait" >&2; exit 1; }
[[ $# -ge 1 ]] || usage
case "$1" in
  push)
    remote="${GIT_REMOTE:-origin}"
    branch="${2:-$(git branch --show-current)}"
    [[ -n "$branch" && "$branch" != "HEAD" ]] || { echo "pass branch or checkout one" >&2; exit 1; }
    git fetch "$remote"
    git pull --rebase "$remote" "$branch"
    git push "$remote" "$branch"
    ;;
  argocd-wait)
    NS="${ARGOCD_NAMESPACE:-argocd}"
    SVC="${ARGOCD_SERVER_SVC:-argocd-server}"
    MAX="${MAX_WAIT_SEC:-600}"
    STEP="${STEP_SEC:-5}"
    t=0
    while (( t < MAX )); do
      ip=$(kubectl get svc "$SVC" -n "$NS" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
      host=$(kubectl get svc "$SVC" -n "$NS" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
      [[ -n "$ip" ]] && echo "https://${ip}" && exit 0
      [[ -n "$host" ]] && echo "https://${host}" && exit 0
      echo "waiting ${t}s / ${MAX}s..."
      sleep "$STEP"
      t=$((t + STEP))
    done
    echo "timeout: kubectl describe svc $SVC -n $NS" >&2
    exit 1
    ;;
  *) usage ;;
esac
