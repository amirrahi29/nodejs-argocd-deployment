# nodejs-argocd-deployment

Express + Helm + Argo CD (branches: `dev`, `main`, `staging`, `uat`).

## Layout

| Path | Purpose |
|------|---------|
| `app/` | Image source |
| `gitops/helm/chat-app` | Chart + `values-<env>.yaml` |
| `gitops/argocd/` | ApplicationSet, platform app, `argocd-server` Service |
| `gitops/project.yaml` | Git URL, Azure (ACR + optional SP ids), image, Helm, AKS |
| `scripts/apply-project-config.py` | `--github-env`, `--sync-files`, `--helm-all`, `--helm-branch`, `--patch-values-image` |
| `scripts/helpers.sh` | `push` \| `argocd-wait` |
| `.github/workflows/ci.yml` | CI, build, Helm, GitOps commits, `argocd-apply` (Azure login: `project.yaml` SP + `AZURE_CLIENT_SECRET`, or `AZURE_CREDENTIALS`) |

**Fork / retarget:** edit `gitops/project.yaml` and push; CI `render` runs `--sync-files` when that file or the script changes.

```bash
pip3 install pyyaml
python3 scripts/apply-project-config.py --sync-files
git diff && git commit …
```

## Azure auth (pick one)

**A — Single secret (legacy):** leave `azure.tenant_id`, `subscription_id`, `client_id` empty in `project.yaml`. GitHub secret **`AZURE_CREDENTIALS`**: full service principal JSON from `az ad sp create-for-rbac --sdk-auth`.

**B — Split (recommended):** set **`azure.tenant_id`**, **`azure.subscription_id`**, **`azure.client_id`** in `gitops/project.yaml`. GitHub secret **`AZURE_CLIENT_SECRET`** only (same SP’s password). `AZURE_CREDENTIALS` not required.

## Ops

- **App rollout (image / Helm values):** Push → build updates `values-*.yaml` → Argo CD **auto-syncs from Git** — no `kubectl` per deploy.
- **Argo Application / ApplicationSet YAML:** On **every push to `main`** (and `workflow_dispatch`), CI job `argocd-apply` runs `kubectl apply -n argocd -f gitops/argocd/applications/` when `aks` is set in `gitops/project.yaml` — idempotent, no manual step in normal use.
- Push/PR: `helm template` validation; build when `app/**` or workflow paths change. Optional `aks.use_admin_kubeconfig: true`.
- One-time: install Argo CD on the cluster once; GitHub secrets as above. Manual `kubectl apply` only if CI is skipped (e.g. `aks` empty) or first bootstrap before Actions is wired.
- Rollback: `git revert` + push, Argo history, or `kubectl rollout undo`.
- Production: branch protection, GitHub→Azure OIDC (no long-lived SP password), Argo Ingress + SSO, Key Vault.

## Commands

```bash
chmod +x scripts/helpers.sh
./scripts/helpers.sh push
./scripts/helpers.sh argocd-wait
python3 scripts/apply-project-config.py --helm-all
```

## CI

`ci.yml`: path filters, `npm audit`, Helm, Docker build, GitOps commits, and **`argocd-apply` on each `main` push** (AKS + secrets configured) to keep Argo app manifests applied automatically.

## Security

Vulnerability reporting: [SECURITY.md](SECURITY.md).

Runtime: non-root pod, read-only root FS, dropped capabilities, `seccompProfile: RuntimeDefault`, `/healthz`, requests/limits in `values.yaml`.
