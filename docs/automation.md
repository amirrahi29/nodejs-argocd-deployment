# Automation scope

Goal: **day-to-day work = push to Git only**. No manual `kubectl` for Argo Application / ApplicationSet updates after one-time setup.

## What runs automatically (after setup)

| Flow | How |
|------|-----|
| Build image + bump `values-<branch>.yaml` | `CI` workflow on `app/**` or `ci.yml` change |
| Validate Helm overlays | `CI` → `helm` job on `gitops/**` or `scripts/**` change |
| Apply `gitops/argocd/applications/*.yaml` to AKS | **`Argo CD cluster sync`** on push to **`main`** when `gitops/argocd/**` changes |
| Sync chat-app to cluster | Argo CD **auto-sync** (ApplicationSet) |
| Sync Argo platform (e.g. LoadBalancer Service) | `argocd-platform` Application **auto-sync** |
| LoadBalancer public IP | Azure assigns when Service type is LoadBalancer |

## One-time setup (cannot be removed in any real system)

1. **Azure + AKS** exist; **Argo CD** is installed on the cluster (marketplace, Helm, or official manifest — not in this repo).
2. **GitHub**: secret **`AZURE_CREDENTIALS`** (and optional **`AZURE_SUBSCRIPTION_ID`**) for CI.
3. **GitHub repository Variables** (Actions → Variables), so cluster sync can run without you:
   - **`AKS_RESOURCE_GROUP`** — e.g. `RahiResource`
   - **`AKS_CLUSTER_NAME`** — e.g. `ChatAppCluster`
4. **Azure RBAC**: the same service principal (or identity CI uses) must be allowed to run **`az aks get-credentials`** on that cluster (e.g. *Azure Kubernetes Service Cluster User Role* or *Cluster Admin*). If sync fails with auth errors, set Variable **`AKS_USE_ADMIN_KUBECONFIG`** to **`true`** (trade-off: admin kubeconfig in automation).

Until variables (3) are set, **`Argo CD cluster sync`** skips the apply job (green run, no cluster changes).

## First push before variables were set

If you already applied manifests manually once, you are fine. After you add Variables, every future change under `gitops/argocd/` merged to **`main`** updates the cluster automatically.

## What is still “manual” by policy (optional)

- **Pull requests / approvals** on `main` (recommended for production).
- **Secrets rotation** (GitHub / Azure).
- **Incident response** (rollback is automatic *in behaviour* if you **revert in Git** and Argo auto-syncs; see [rollback.md](rollback.md)).

No CI pipeline can create an empty Azure subscription or install Argo into a cluster that does not exist — that remains platform onboarding.
