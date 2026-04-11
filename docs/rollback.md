# Rollback (Argo CD + Git + Kubernetes)

## 1. GitOps-first (recommended)

Source of truth is **Git**. To roll back **what Argo deploys**:

1. **Revert the bad commit** (or restore an old `values-<env>.yaml` image tag) on the branch that env tracks (`dev` / `main` / …).
2. **Push**; CI may rebuild if `app/**` changed.
3. With **auto-sync** (your ApplicationSet / platform app), Argo applies the reverted state **without** opening the UI — fully automatic once Git is fixed.

```bash
git revert <bad-commit-sha>   # or git checkout <old-commit> -- path/to/file
git pull --rebase origin <branch> && git push origin <branch>
```

For **image only**: edit `gitops/helm/chat-app/values-<env>.yaml` → set `image.tag` to a known-good tag (e.g. `dev-abc1234`) → commit → push → Argo sync.

## 2. Argo CD UI / CLI (fast, same cluster)

Roll back the **last synced Git revision** without waiting for a new Git commit:

**UI:** Application → **History** → pick a healthy revision → **Rollback** (or **Redeploy** that revision).

**CLI:**

```bash
argocd app history chat-app-dev
argocd app rollback chat-app-dev <revision-id>
```

Use the app name your ApplicationSet created (`chat-app-dev`, `chat-app-main`, …).

Note: With **auto-sync**, Argo may move forward again to match **current Git**. Lasting rollback usually means **fixing Git** (section 1) or **temporarily disabling auto-sync** for that app.

## 3. Kubernetes only (emergency, not durable)

Undo the **Deployment** rollout (previous ReplicaSet). Argo can **fight** this if auto-sync is on and Git still points at the new image.

```bash
kubectl rollout undo deployment/<release-name> -n <namespace>
kubectl rollout status deployment/<release-name> -n <namespace>
```

Release name is usually the Helm release name; check with `kubectl get deploy -n dev`.

## What to use when

| Situation | Prefer |
|-----------|--------|
| Bad code / wrong image tag in Git | **Git revert** or fix `image.tag` + push |
| Need instant revert, then fix Git | **Argo rollback**, then **Git** to match |
| Argo down / cluster-only emergency | **`kubectl rollout undo`**, then align Git |

## After rollback

- Confirm **Argo app** is **Synced** and **Healthy**.
- Optionally run **`helm template`** locally for that env before pushing next change.
