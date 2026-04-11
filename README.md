# nodejs-argocd-deployment

Express + Helm + Argo CD (one Git branch per env: `dev` / `main` / `staging` / `uat`).

## Layout

| Path | Purpose |
|------|---------|
| `app/` | Image source |
| `gitops/helm/chat-app` | Chart + `values-<env>.yaml` |
| `gitops/argocd/` | ApplicationSet, platform app, `argocd-server` Service |
| `scripts/helpers.sh` | `push` \| `argocd-wait` |
| `scripts/helm-template-overlays.sh` | `helm template` all overlays or one branch |

**Fork:** set `repoURL` in `gitops/argocd/applications/*.yaml`. **CI env:** `.github/workflows/ci.yml` (`ACR_*`, `IMAGE_NAME`, `CHART`).

## Ops (short)

- **Auto:** every push/PR runs **`helm template`** on all overlays; build + image bump only when `app/**` or workflow files change; on `main`, `argocd-cluster-sync` applies `gitops/argocd/applications/` if **`AKS_RESOURCE_GROUP`** + **`AKS_CLUSTER_NAME`** are set. Optional **`AKS_USE_ADMIN_KUBECONFIG=true`** if `get-credentials` fails.
- **One-time:** Azure + AKS + Argo on cluster; GitHub secret **`AZURE_CREDENTIALS`** (optional **`AZURE_SUBSCRIPTION_ID`**).
- **Rollback:** `git revert` + push (auto-sync), or Argo **History → Rollback** (temporary if auto-sync on), or `kubectl rollout undo` (emergency).
- **Hardening (portal):** protect `main`, OIDC to Azure instead of long-lived SP, Ingress+TLS for Argo, Key Vault for app secrets.

## Commands

```bash
chmod +x scripts/helpers.sh   # once
./scripts/helpers.sh push
./scripts/helpers.sh argocd-wait
bash scripts/helm-template-overlays.sh gitops/helm/chat-app
```

Without AKS Variables: `kubectl apply -n argocd -f gitops/argocd/applications/`.

## CI

`ci.yml` — path filters + image bump (inline Python patch); `argocd-cluster-sync.yml` — apply Argo apps to AKS from `main`.
