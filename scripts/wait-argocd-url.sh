#!/usr/bin/env bash
# Waits until Azure/cloud sets argocd-server LoadBalancer IP/hostname, then prints URLs.
set -euo pipefail
NS="${ARGOCD_NAMESPACE:-argocd}"
SVC="${ARGOCD_SERVER_SVC:-argocd-server}"
MAX_WAIT_SEC="${MAX_WAIT_SEC:-600}"
STEP="${STEP_SEC:-5}"

elapsed=0
while (( elapsed < MAX_WAIT_SEC )); do
  ip=$(kubectl get svc "$SVC" -n "$NS" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  host=$(kubectl get svc "$SVC" -n "$NS" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  if [[ -n "$ip" ]]; then
    echo "Argo CD UI: https://${ip}"
    echo "           http://${ip}   (redirects to HTTPS)"
    exit 0
  fi
  if [[ -n "$host" ]]; then
    echo "Argo CD UI: https://${host}"
    exit 0
  fi
  echo "Waiting for ${SVC} external endpoint... (${elapsed}s / ${MAX_WAIT_SEC}s)"
  sleep "$STEP"
  elapsed=$((elapsed + STEP))
done
echo "Timed out. Check: kubectl describe svc $SVC -n $NS" >&2
exit 1
