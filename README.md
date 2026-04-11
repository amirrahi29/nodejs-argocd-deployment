# nodejs-argocd-deployment

Node app (`app/`), Helm chart (`gitops/helm/chat-app`), Argo CD ApplicationSet (`gitops/argocd/`).

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

Then `kubectl get svc argocd-server -n argocd` for the external IP and open `https://<IP>`. If Argo was installed with Helm and labels differ, adjust the `Service` `selector` to match your install.

## CI

`.github/workflows/ci.yml`: GitOps-only changes run `helm template` on all overlays; app (or workflow) changes build, push to ACR, patch `values-<branch>.yaml`, then commit with `git pull --rebase` retries.
