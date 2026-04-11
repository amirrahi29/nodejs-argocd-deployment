# Industry-standard alignment (checklist)

Your repo already follows several good practices: GitOps with Argo CD, CI with path filters, Helm overlays per environment, `DEPLOY_ENV`, Argo server config in Git, and safe push scripting.

Below is how teams usually tighten this for **production** and **compliance**. Items marked **(portal)** are done in GitHub / Azure / Argo UI, not in this repository.

## Source control & delivery

| Practice | Your repo | Typical next step |
|----------|-----------|-------------------|
| Protected `main` | **(portal)** | Require PR, 1+ review, required CI checks, block force-push |
| Linear history | Partial | Keep `pull.rebase true`; optional “Require linear history” on `main` |
| Long-lived env branches | You use them | **Common** in smaller setups; larger orgs often use **one trunk** + `values-prod.yaml` / folders + promotion; both are valid if process is clear |
| Signed commits / tags | Optional | Tag releases; verify in CI for prod deploys |

## CI/CD & cloud identity

| Practice | Your repo | Typical next step |
|----------|-----------|-------------------|
| Least-privilege deploy identity | `AZURE_CREDENTIALS` (client secret) | Prefer **OIDC federation** (GitHub → Azure AD workload identity) and **short-lived tokens** **(portal + workflow)** |
| Immutable artifacts | Tags like `dev-<sha>` | Add **image digest** in Helm when pinning; optional **Trivy/Defender** scan in CI |
| Secrets in CI | GitHub Secrets | Rotate regularly; scope secrets to environments **(portal)** |

## Kubernetes & GitOps

| Practice | Your repo | Typical next step |
|----------|-----------|-------------------|
| Health probes | Added in chart | Tune `initialDelaySeconds` / `timeoutSeconds` under load |
| Resource requests/limits | Optional in values | Set **requests + limits** per env to avoid noisy neighbour **(values)** |
| Pod security | Default | Consider **restricted** PSA, **non-root** container **(Dockerfile + chart)** |
| Argo access | LoadBalancer | Move to **Ingress + TLS** (cert-manager), **disable** wide-open admin, **Azure AD SSO** **(portal)** |
| AppProjects | `default` | Split **prod** vs **nonprod** projects with **source/destination** restrictions **(Argo)** |
| Drift / sync | Auto sync | Prod: often **manual sync** or **sync windows** + notifications |

## Security & compliance

| Practice | Your repo | Typical next step |
|----------|-----------|-------------------|
| App secrets in Git | Avoid | **Azure Key Vault** + CSI driver or **External Secrets** |
| Argo admin password | Initial secret | Change once; prefer **SSO**; remove reliance on `argocd-initial-admin-secret` |
| Network | Public LBs | **NSG**, optional **private AKS** + **internal** LB / VPN for Argo |

## Operations

| Practice | Your repo | Typical next step |
|----------|-----------|-------------------|
| Logging / metrics | **(cluster)** | Azure Monitor / Container Insights or Prometheus stack |
| Runbooks | This doc | Add incident steps (Argo stuck, LB pending, image pull errors) |
| Backup | **(cluster)** | Etcd / Velero for cluster state if required by policy |

## Suggested order (pragmatic)

1. **Branch protection** + required checks on `main` **(GitHub)**  
2. **Change Argo admin** + plan **Ingress + TLS** or **internal LB**  
3. **OIDC** for GitHub → Azure **(replace long-lived SP secret)**  
4. **Key Vault** (or similar) for any future app secrets  
5. **Resource limits** + **security context** in Helm/Dockerfile  

This file is guidance only; implement items based on your threat model and team size.
