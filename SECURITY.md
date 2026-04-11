# Security

## Reporting

Please report suspected vulnerabilities via [GitHub Security Advisories](https://github.com/amirrahi29/nodejs-argocd-deployment/security/advisories/new) (private disclosure) instead of a public issue.

Include steps to reproduce, affected versions or branches, and impact if known.

## Practices in this repo

- Container runs as non-root (`USER node`), read-only root filesystem with `/tmp` emptyDir, dropped capabilities, `seccompProfile: RuntimeDefault`.
- CI runs `npm audit` at **high** severity on app changes and pull requests.
- Dependabot opens weekly PRs for `npm` and GitHub Actions.

Rotate **`AZURE_CREDENTIALS`** and Argo admin access regularly; prefer OIDC federation for Azure in production.
