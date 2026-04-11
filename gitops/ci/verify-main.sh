#!/usr/bin/env bash
# Post-deploy: rollout + Argo health + in-cluster /healthz; Argo rollback if checks fail.
# GitHub Actions sets VERIFY_* from the push branch; this repo defaults to uat for local runs.
set -euo pipefail

NS_APP="${VERIFY_NAMESPACE:-uat}"
P="${ARGO_APP_PREFIX:-chat-app}"
C="${HELM_CHART_NAME:-chat-app}"
DEPLOY="${VERIFY_DEPLOYMENT:-${P}-uat-${C}}"
ARGO_APP="${VERIFY_ARGO_APP:-${P}-uat}"
ARGO_NS="${VERIFY_ARGO_NS:-argocd}"
ROLLOUT_TIMEOUT="${VERIFY_ROLLOUT_TIMEOUT:-5m}"
ARGO_WAIT_SEC="${VERIFY_ARGO_WAIT_SEC:-600}"
STEP="${VERIFY_POLL_SEC:-15}"
SKIP_ROLLBACK="${VERIFY_SKIP_ROLLBACK:-0}"
SMOKE_JOB="smoke-${GITHUB_RUN_ID:-local}"

rollback() {
  if [[ "$SKIP_ROLLBACK" == "1" ]]; then
    echo "::warning::VERIFY_SKIP_ROLLBACK=1 — not rolling back."
    return 0
  fi
  echo "::error::Attempting Argo CD rollback: $ARGO_APP"
  if ! command -v argocd >/dev/null 2>&1; then
    echo "::warning::argocd CLI missing — set up rollback manually or fix install step."
    return 1
  fi
  argocd login --core
  argocd app rollback "$ARGO_APP" || echo "::warning::Rollback CLI failed (RBAC, or no history yet)."
}

echo "Initial pause for Git + Argo to reconcile..."
sleep "${VERIFY_INITIAL_SLEEP:-35}"

echo "Waiting for Deployment rollout ($DEPLOY / $NS_APP)..."
if ! kubectl rollout status "deployment/$DEPLOY" -n "$NS_APP" --timeout="$ROLLOUT_TIMEOUT"; then
  echo "::error::Rollout failed or timed out."
  rollback || true
  exit 1
fi

health="Unknown"
sync="Unknown"
elapsed=0
degraded=0
while [[ $elapsed -lt "$ARGO_WAIT_SEC" ]]; do
  health=$(kubectl get application "$ARGO_APP" -n "$ARGO_NS" -o jsonpath='{.status.health.status}' 2>/dev/null || echo Unknown)
  sync=$(kubectl get application "$ARGO_APP" -n "$ARGO_NS" -o jsonpath='{.status.sync.status}' 2>/dev/null || echo Unknown)
  echo "Argo CD app $ARGO_APP: health=$health sync=$sync (${elapsed}s / ${ARGO_WAIT_SEC}s)"
  if [[ "$health" == "Healthy" && "$sync" == "Synced" ]]; then
    break
  fi
  if [[ "$health" == "Degraded" ]]; then
    degraded=1
    break
  fi
  sleep "$STEP"
  elapsed=$((elapsed + STEP))
done

if [[ "$degraded" == 1 ]]; then
  echo "::error::Argo reports Degraded."
  rollback || true
  exit 1
fi

if [[ "$health" != "Healthy" || "$sync" != "Synced" ]]; then
  echo "::error::Timeout waiting for Healthy+Synced (health=$health sync=$sync)."
  rollback || true
  exit 1
fi

URL="http://${DEPLOY}.${NS_APP}.svc.cluster.local:3000/healthz"
echo "Smoke Job: GET $URL"
kubectl delete job -n "$NS_APP" "$SMOKE_JOB" --ignore-not-found >/dev/null 2>&1 || true

kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${SMOKE_JOB}
  namespace: ${NS_APP}
spec:
  ttlSecondsAfterFinished: 120
  backoffLimit: 1
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: curl
          image: curlimages/curl:8.5.0
          command:
            - curl
            - -sfS
            - --connect-timeout
            - "30"
            - ${URL}
EOF

smoke_ok=0
for _ in $(seq 1 40); do
  succeeded=$(kubectl get job "$SMOKE_JOB" -n "$NS_APP" -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "")
  failed=$(kubectl get job "$SMOKE_JOB" -n "$NS_APP" -o jsonpath='{.status.failed}' 2>/dev/null || echo "")
  if [[ "${succeeded:-0}" == "1" ]]; then
    smoke_ok=1
    break
  fi
  if [[ -n "${failed:-}" && "${failed:-0}" -ge 1 ]] 2>/dev/null; then
    echo "::error::Smoke Job failed."
    kubectl logs -n "$NS_APP" "job/$SMOKE_JOB" --all-containers=true 2>/dev/null || true
    kubectl delete job -n "$NS_APP" "$SMOKE_JOB" --ignore-not-found || true
    rollback || true
    exit 1
  fi
  sleep 3
done

if [[ "$smoke_ok" != "1" ]]; then
  echo "::error::Smoke Job timed out."
  kubectl logs -n "$NS_APP" "job/$SMOKE_JOB" --all-containers=true 2>/dev/null || true
  kubectl delete job -n "$NS_APP" "$SMOKE_JOB" --ignore-not-found || true
  rollback || true
  exit 1
fi
echo "Smoke Job succeeded."

kubectl delete job -n "$NS_APP" "$SMOKE_JOB" --ignore-not-found || true
echo "Deploy verify OK (rollout + Argo + smoke)."
