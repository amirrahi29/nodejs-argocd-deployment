# nodejs-argocd-deployment

Express + Helm + Argo CD (one Git branch per env: `dev` / `main` / `staging` / `uat`).

## Layout

| Path | Purpose |
|------|---------|
| `app/` | Image source |
| `gitops/helm/chat-app` | Chart + `values-<env>.yaml` |
| `gitops/argocd/` | ApplicationSet, platform app, `argocd-server` Service |
| `config/project.yaml` | **Single file:** Git URL, ACR, image name, Helm chart path, versions |
| `scripts/apply-project-config.py` | CI reads env from it; `--sync-files` patches Argo + `values.yaml` |
| `scripts/helpers.sh` | `push` \| `argocd-wait` |
| `scripts/helm-template-overlays.sh` | `helm template` all overlays or one branch |

**New project / fork:** edit **`config/project.yaml`** only, then:

```bash
pip3 install pyyaml   # or: brew install libyaml && … ; CI has python3-yaml
python3 scripts/apply-project-config.py --sync-files
git diff   # review updates to Argo manifests + values.yaml default image
git commit -am "chore: apply project config"
```

CI reads **`config/project.yaml`** at runtime (`--github-env`), so ACR/build use it without re-running sync — but Argo YAML in Git must match (run `--sync-files` before push). **AKS** `resource_group` / `cluster_name` are in the same file under **`aks:`** (cluster sync skips if that block is empty).

## Ops (short)

- **Auto:** every push/PR runs **`helm template`**; build + image bump when `app/**` or workflow changes; on `main`, `argocd-cluster-sync` applies Argo apps when **`config/project.yaml`** has **`aks.resource_group`** + **`aks.cluster_name`**. Optional **`aks.use_admin_kubeconfig: true`**.
- **One-time (cannot live in Git):** Argo installed on cluster; GitHub secrets **`AZURE_CREDENTIALS`** (optional **`AZURE_SUBSCRIPTION_ID`**). **`CODEOWNERS` / `SECURITY.md`** mein apna handle/repo URL ek baar.
- **Rollback:** `git revert` + push (auto-sync), or Argo **History → Rollback** (temporary if auto-sync on), or `kubectl rollout undo` (emergency).
- **Hardening (portal):** protect `main`, OIDC to Azure instead of long-lived SP, Ingress+TLS for Argo, Key Vault for app secrets.

## Commands

```bash
chmod +x scripts/helpers.sh   # once
./scripts/helpers.sh push
./scripts/helpers.sh argocd-wait
bash scripts/helm-template-overlays.sh gitops/helm/chat-app
```

If **`aks:`** empty: `kubectl apply -n argocd -f gitops/argocd/applications/` manually once if needed.

## CI

`ci.yml` — path filters, **`npm audit`** (high+) on PRs / app changes, **`helm template`** every run, Docker build when `app/**` or workflow changes; `argocd-cluster-sync.yml` — apply Argo apps to AKS from `main`. PR concurrency cancels superseded runs.

## Enterprise / governance

| Item | Location |
|------|----------|
| Vulnerability reporting | [SECURITY.md](SECURITY.md) |
| Default reviewers | [.github/CODEOWNERS](.github/CODEOWNERS) |
| Dependency & Actions updates | [.github/dependabot.yml](.github/dependabot.yml) |
| PR checklist | [.github/pull_request_template.md](.github/pull_request_template.md) |

**Runtime:** non-root pod, read-only root FS, dropped capabilities, `seccompProfile: RuntimeDefault`, `/healthz` for probes, default **requests/limits** in `values.yaml`. Next steps in production: branch protection, GitHub → Azure **OIDC**, Argo **Ingress + SSO**, **Key Vault** for secrets.
