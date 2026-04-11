# nodejs-argocd-deployment

Express + Helm + Argo CD (branches: `dev`, `main`, `staging`, `uat`).

## Layout

| Path | Purpose |
|------|---------|
| `app/` | Image source |
| `gitops/helm/chat-app` | Chart + `values-<env>.yaml` |
| `gitops/argocd/` | ApplicationSet, platform app, `argocd-server` Service |
| `gitops/project.yaml` | Git URL, Azure (ACR + optional SP ids), image, Helm, AKS |
| `gitops/apply-project-config.py` | CI + local: env export, Argo/values sync, Helm template, image patch |
| `gitops/ci/verify-main.sh` | **main** production checks (rollout, Argo health, `/healthz`); optional Argo rollback |
| `.github/workflows/ci.yml` | **Application delivery pipeline** — audit, Helm validation, optional build/publish, GitOps commits, Argo CD apply (Azure: `project.yaml` SP + `AZURE_CLIENT_SECRET`, or `AZURE_CREDENTIALS`) |

**Fork / retarget:** edit `gitops/project.yaml` and push; job **GitOps — render manifests** runs `--sync-files` when that file or the script changes.

```bash
pip3 install pyyaml
python3 gitops/apply-project-config.py --sync-files
git diff && git commit …
```

## Azure auth (pick one)

**A — Single secret (legacy):** leave `azure.tenant_id`, `subscription_id`, `client_id` empty in `project.yaml`. GitHub secret **`AZURE_CREDENTIALS`**: full service principal JSON from `az ad sp create-for-rbac --sdk-auth`.

**B — Split (recommended):** set **`azure.tenant_id`**, **`azure.subscription_id`**, **`azure.client_id`** in `gitops/project.yaml`. GitHub secret **`AZURE_CLIENT_SECRET`** only (same SP’s password). `AZURE_CREDENTIALS` not required.

## Ops

- **App rollout (image / Helm values):** Push → build updates `values-*.yaml` → Argo CD **auto-syncs from Git** — no `kubectl` per deploy.
- **Argo Application / ApplicationSet YAML:** On **every push to `main`** (and **Run workflow**), job **Cluster — sync Argo CD application manifests** runs `kubectl apply -n argocd -f gitops/argocd/applications/` when `aks` is set in `gitops/project.yaml` (idempotent).
- Push/PR: `helm template` validation; **Docker build + ACR push** only when `app/**` changes (or **Actions → Run workflow** manually). Optional `aks.use_admin_kubeconfig: true`.
- One-time: install Argo CD on the cluster once; GitHub secrets as above. Manual `kubectl apply` only if the pipeline skips cluster apply (e.g. `aks` empty) or during first bootstrap.
- **Automated verify (main):** After a **main** push that changes **`app/**` or `gitops/**`** (e.g. image bump), job **Production — verify health & automatic rollback** waits for Deployment rollout, **Argo CD `Healthy` + `Synced`**, then runs an in-cluster **smoke Job** against `/healthz`. On failure it runs **`argocd app rollback`** (CLI **core** mode, same kubeconfig as CI). Set env **`VERIFY_SKIP_ROLLBACK=1`** in the workflow step if you only want checks without rollback. Large teams often add **Argo Rollouts** + Prometheus analysis on top; this is a lighter GitHub Actions gate.
- **Manual rollback:** `git revert` + push, Argo UI **History → Rollback**, or emergency `kubectl rollout undo` (self-heal may fight GitOps).
- Production: branch protection, GitHub→Azure OIDC (no long-lived SP password), Argo Ingress + SSO, Key Vault.

## Commands

```bash
python3 gitops/apply-project-config.py --helm-all
python3 gitops/apply-project-config.py --sync-files
```

## Pipeline

Workflow **Application delivery pipeline** (`ci.yml`): path detection, `npm audit`, Helm validation, Docker build/publish (only `app/**` or manual run), GitOps commits, **Argo CD apply on each `main` push**, and **production verify + optional Argo rollback** when AKS is set and the push touches `app` or `gitops` (or **Run workflow**). CI identity needs rights to read workloads in namespace **`main`** and to update **`applications.argoproj.io`** in **`argocd`** for rollback to succeed.

## Security

Vulnerability reporting: [SECURITY.md](SECURITY.md).

Runtime: non-root pod, read-only root FS, dropped capabilities, `seccompProfile: RuntimeDefault`, `/healthz`, requests/limits in `values.yaml`.
