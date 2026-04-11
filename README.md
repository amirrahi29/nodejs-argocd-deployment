# nodejs-argocd-deployment

Express app, Helm chart, and Argo CD ApplicationSet (one Git branch per environment).

**Docs:** [automation](docs/automation.md) · [industry alignment](docs/industry-alignment.md) · [rollback](docs/rollback.md)

## Layout

| Path | Purpose |
|------|---------|
| `app/` | Container image source |
| `gitops/helm/chat-app` | Chart, `values.yaml`, `values-<env>.yaml` |
| `gitops/argocd/` | ApplicationSet, `argocd-platform` app, `argocd-server` Service |
| `scripts/` | `git-push.sh`, `wait-argocd-url.sh`, `helm-template-overlays.sh`, `patch-values-image.py` |
| `.github/workflows` | `ci.yml`, `argocd-cluster-sync.yml` |
| `.github/actions/azure-subscription` | Shared `az account set` step for workflows |

**Reuse / fork:** set `repoURL` in `gitops/argocd/applications/applicationset.yaml` and `argocd-platform-application.yaml`. Tune `env` in `.github/workflows/ci.yml` (`ACR_*`, `IMAGE_NAME`, `CHART`, `HELM_VERSION`).

## Branches

| Branch | Argo tracks | K8s namespace |
|--------|-------------|----------------|
| `main` | `main` | `main` |
| `dev` | `dev` | `dev` |
| `staging` | `staging` | `staging` |
| `uat` | `uat` | `uat` |

One Argo CD URL for every env; per-env app LoadBalancers differ.

## Useful commands

```bash
./scripts/git-push.sh
./scripts/wait-argocd-url.sh
```

If GitHub Variables `AKS_RESOURCE_GROUP` / `AKS_CLUSTER_NAME` are unset: `kubectl apply -n argocd -f gitops/argocd/applications/` once. See [automation.md](docs/automation.md).

## CI (summary)

- **CI:** path filters → Helm validate all overlays (`scripts/helm-template-overlays.sh`) or Docker build + `patch-values-image.py` + push GitOps bump.
- **Argo CD cluster sync:** applies `gitops/argocd/applications/` to AKS on `main` when that tree changes.
