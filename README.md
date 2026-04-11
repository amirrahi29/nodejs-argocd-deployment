# nodejs-argocd-deployment

**Default branch for day-to-day work: `dev`.** CI applies Argo manifests to the cluster and runs post-deploy verify **only on pushes to `dev`** (plus manual `workflow_dispatch`).

Node app (`app/`), Helm chart (`gitops/helm/chat-app`), Argo CD manifests under `gitops/argocd/applications/` (generated from `gitops/project.yaml`).

## Branches and environments

| Branch    | Argo `targetRevision` | Kubernetes namespace |
|-----------|------------------------|----------------------|
| `main`    | `main`                 | `main`               |
| `dev`     | `dev`                  | `dev`                |
| `staging` | `staging`              | `staging`            |
| `uat`     | `uat`                  | `uat`                |

Each branch carries its own overlay (`values-<branch>.yaml`). CI may append commits (image tag bumps or `--sync-files`); always `git pull --rebase` before you push.

## Project config (single source of truth)

Edit `gitops/project.yaml`, then regenerate committed manifests:

```bash
python3 gitops/apply-project-config.py --sync-files
```

This updates `00-appprojects.yaml`, `applicationset.yaml`, `argocd-platform-application.yaml`, and base `values.yaml` image repository. On **dev** this repo uses `git.platform_branch: dev` so the platform Application tracks the `dev` branch.

## Git: push rejected (“fetch first”)

Remote may have bot commits. **Do not** force-push unless you intend to drop them.

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

- **Path detection** — `app/**`, `gitops/**`, and `gitops/project.yaml` + `apply-project-config.py`.
- **Audit** — `npm audit` on PRs or when `app/` changes.
- **Render** — on push when project config changes: `--sync-files` and commit.
- **Helm** — `helm template` for every `values-*.yaml` via `apply-project-config.py --helm-all`.
- **Build** — on push when `app/` changes (or manual): ACR build/push, patch `values-<branch>.yaml`, validate template, commit.
- **argocd-apply** — on push to **`dev`** (or manual): `kubectl apply` under `gitops/argocd/applications/` when AKS is set in `project.yaml`.
- **verify-deployed** — after apply, on **`dev`** push when app or gitops changed (or manual): rollout, Argo Healthy+Synced, in-cluster smoke on `/healthz`, optional rollback.

Azure: either fill `tenant_id`, `subscription_id`, `client_id` in `project.yaml` and use `AZURE_CLIENT_SECRET`, or leave them empty and use `AZURE_CREDENTIALS` JSON.
