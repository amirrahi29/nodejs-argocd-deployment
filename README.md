# nodejs-argocd-deployment

Node app (`app/`), Helm chart (`gitops/helm/chat-app`), Argo CD ApplicationSet (`gitops/argocd/`). For a production-style checklist (branch protection, OIDC, Ingress, secrets), see [docs/industry-alignment.md](docs/industry-alignment.md). For rollbacks (Git vs Argo vs `kubectl`), see [docs/rollback.md](docs/rollback.md).

## Branches and environments

| Branch   | Argo `targetRevision` | Kubernetes namespace |
|----------|------------------------|----------------------|
| `main`   | `main`                 | `main`               |
| `dev`    | `dev`                  | `dev`                |
| `staging`| `staging`              | `staging`            |
| `uat`    | `uat`                  | `uat`                |

Each branch carries its own GitOps overlay (`values-<branch>.yaml`). CI may append commits (image tag bumps); always integrate remote before you push.

**Argo CD** is installed **once** per cluster (`argocd` namespace). There is **one UI URL** for every environment: you manage `chat-app-dev`, `chat-app-main`, `chat-app-staging`, and `chat-app-uat` as separate Applications in that same Argo. Only the **chat-app** LoadBalancers (per namespace) differ per env.

## Git: push rejected (“fetch first”)

That means `origin/<branch>` has commits you do not have (often the GitHub Actions bot after a build). **Do not** force-push to recover unless you intend to drop remote commits.

```bash
git fetch origin
git pull --rebase origin <branch>
git push origin <branch>
```

Or use the helper (same steps):

```bash
chmod +x scripts/git-push.sh   # once
./scripts/git-push.sh          # current branch
./scripts/git-push.sh dev      # explicit branch
```

Recommended local defaults (linear history, fewer surprise merge commits):

```bash
git config pull.rebase true
git config fetch.prune true
```

## Argo CD UI on LoadBalancer (GitOps)

This is **not** per-environment: one `argocd-server` LoadBalancer is the single entry point for all envs. Manifests live under `gitops/argocd/platform/` (`argocd-server` → `type: LoadBalancer`). One-time bootstrap so Argo syncs that folder from `main`:

```bash
kubectl apply -n argocd -f gitops/argocd/applications/argocd-platform-application.yaml
```

The cloud control plane assigns the public IP **automatically** when the Service becomes `LoadBalancer`; you do not set the IP in Git. To **wait and print** the URL (no manual `kubectl get` loop):

```bash
chmod +x scripts/wait-argocd-url.sh   # once
./scripts/wait-argocd-url.sh
```

Optional: `MAX_WAIT_SEC=900 ./scripts/wait-argocd-url.sh`

If Argo was installed with Helm and labels differ, adjust the `Service` `selector` in `gitops/argocd/platform/argocd-server-service.yaml` to match your install.

## CI

`.github/workflows/ci.yml`: GitOps-only changes run `helm template` on all overlays; app (or workflow) changes build, push to ACR, patch `values-<branch>.yaml`, then commit with `git pull --rebase` retries.
