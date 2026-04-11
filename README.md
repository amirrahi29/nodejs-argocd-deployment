# nodejs-argocd-deployment

Node app (`app/`), Helm chart (`gitops/helm/chat-app`), Argo CD manifests under `gitops/argocd/applications/` (generated from `gitops/project.yaml` via `apply-project-config.py`).

## Branching model (recommended)

| Role | Branch |
|------|--------|
| **Default / integration** | `main` — GitHub default branch; **only `main` pushes** trigger **kubectl apply** to the cluster (when GitOps, workflow, or project config changes). |
| **Environments** | `dev`, `staging`, `uat`, `main` — each has `values-<branch>.yaml`; ApplicationSet syncs per env (see generated `applicationset.yaml`). |
| **Feature work** | Short-lived branches → **PR into `main`**. |

Other branches (`dev`, `staging`, `uat`) can still **build and push images** and bump their overlay; they **do not** apply Argo root manifests to the cluster, avoiding conflicting writers.

## Project config

```bash
python3 gitops/apply-project-config.py --sync-files    # refresh committed YAML + base values
python3 gitops/apply-project-config.py --helm-all     # validate all overlays
```

`git.platform_branch` should stay **`main`** so the **argocd-platform** Application tracks stable platform manifests.

## CI

Workflow **Application delivery pipeline** (`.github/workflows/ci.yml`):

- **Render** (bot commit from `project.yaml`): **only on `main`** when `gitops/project.yaml` or `apply-project-config.py` changes.
- **Helm validate all overlays**: on PRs, or when `gitops/**`, project config, or workflow changes.
- **Build**: when `app/**` changes (any listed branch).
- **argocd-apply**: **`main` only**, and only when `gitops/**`, project config, or `.github/workflows/**` changes — or **workflow_dispatch**.
- **verify-main**: after a successful apply on `main`, when `app` or `gitops` changed (or manual).

Azure: SP fields in `project.yaml` + `AZURE_CLIENT_SECRET`, or `AZURE_CREDENTIALS` JSON.

## Git

If push is rejected after a bot commit:

```bash
git pull --rebase origin main
git push origin main
```
