# nodejs-argocd-deployment

**Default branch for day-to-day work on this line: `staging`.** CI applies Argo manifests to the cluster and runs post-deploy verify **only on pushes to `staging`** (plus manual `workflow_dispatch`). Layout matches the **dev** branch pattern (`gitops/project.yaml`, `apply-project-config.py`, AppProjects + ApplicationSet).

Node app (`app/`), Helm chart (`gitops/helm/chat-app`), Argo CD manifests under `gitops/argocd/applications/` (generated from `gitops/project.yaml`).

## Branches and environments

| Branch    | Argo `targetRevision` | Kubernetes namespace |
|-----------|------------------------|----------------------|
| `main`    | `main`                 | `main`               |
| `dev`     | `dev`                  | `dev`                |
| `staging` | `staging`              | `staging`            |
| `uat`     | `uat`                  | `uat`                |

Each branch carries its own overlay (`values-<branch>.yaml`). CI may append commits; always `git pull --rebase` before you push.

## Project config (single source of truth)

Edit `gitops/project.yaml`, then:

```bash
python3 gitops/apply-project-config.py --sync-files
```

On **staging**, `git.platform_branch: staging` so the **argocd-platform** Application tracks the `staging` branch.

## Git: push rejected (“fetch first”)

```bash
git fetch origin
git pull --rebase origin <branch>
git push origin <branch>
```

Recommended:

```bash
git config pull.rebase true
git config fetch.prune true
```

## CI

Workflow: **Application delivery pipeline** (`.github/workflows/ci.yml`).

- Path detection, **audit**, **render** (on `project.yaml` / script change), **Helm** validate all overlays, **build** when `app/` changes, **argocd-apply** on **`staging` push** (or manual), **verify-deployed** for **`staging`** after apply.

Azure: SP fields in `project.yaml` + `AZURE_CLIENT_SECRET`, or `AZURE_CREDENTIALS` JSON.
