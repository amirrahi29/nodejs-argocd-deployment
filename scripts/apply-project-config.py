#!/usr/bin/env python3
"""config/project.yaml → GITHUB_ENV lines and/or patch repo URLs & image in tracked YAML (no full re-dump)."""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
CFG_PATH = ROOT / "config" / "project.yaml"


def load_cfg() -> dict:
    if not CFG_PATH.is_file():
        print(f"error: missing {CFG_PATH}", file=sys.stderr)
        sys.exit(1)
    data = yaml.safe_load(CFG_PATH.read_text())
    if not isinstance(data, dict):
        sys.exit("error: project.yaml must be a mapping")
    return data


def github_env_lines(c: dict) -> str:
    az, app, h = c["azure"], c["app"], c["helm"]
    lines = [
        f"ACR_NAME={az['acr_name']}",
        f"ACR_LOGIN_SERVER={az['acr_login_server']}",
        f"IMAGE_NAME={app['image_name']}",
        f"CHART={h['chart_path']}",
        f"HELM_VERSION={h['version']}",
    ]
    aks = c.get("aks") or {}
    rg, cn = aks.get("resource_group"), aks.get("cluster_name")
    if rg and cn:
        lines.append(f"AKS_RESOURCE_GROUP={rg}")
        lines.append(f"AKS_CLUSTER_NAME={cn}")
        if aks.get("use_admin_kubeconfig"):
            lines.append("AKS_USE_ADMIN_KUBECONFIG=true")
    return "\n".join(lines) + "\n"


def sync_files(c: dict) -> None:
    repo_url = c["git"]["repo_url"]
    platform_branch = c["git"]["platform_branch"]
    chart_path = c["helm"]["chart_path"]
    login = c["azure"]["acr_login_server"]
    image = c["app"]["image_name"]
    repo_full = f"{login}/{image}"

    app_set = ROOT / "gitops/argocd/applications/applicationset.yaml"
    t = app_set.read_text()
    t = re.sub(r"^(\s*repoURL:\s*).+$", rf"\g<1>{repo_url}", t, flags=re.M, count=1)
    t = re.sub(r"^(\s*path:\s*).+$", rf"\g<1>{chart_path}", t, flags=re.M, count=1)
    app_set.write_text(t)

    plat = ROOT / "gitops/argocd/applications/argocd-platform-application.yaml"
    t = plat.read_text()
    t = re.sub(r"^(\s*repoURL:\s*).+$", rf"\g<1>{repo_url}", t, flags=re.M, count=1)
    t = re.sub(
        r"^(\s*targetRevision:\s*).+$",
        rf"\g<1>{platform_branch}",
        t,
        flags=re.M,
        count=1,
    )
    plat.write_text(t)

    values = ROOT / chart_path / "values.yaml"
    dv = yaml.safe_load(values.read_text())
    dv.setdefault("image", {})
    dv["image"]["repository"] = repo_full
    values.write_text(yaml.dump(dv, default_flow_style=False, sort_keys=False))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--github-env", action="store_true")
    ap.add_argument("--sync-files", action="store_true")
    args = ap.parse_args()
    if not args.github_env and not args.sync_files:
        ap.error("pass --github-env and/or --sync-files")
    c = load_cfg()
    if args.github_env:
        sys.stdout.write(github_env_lines(c))
    if args.sync_files:
        sync_files(c)


if __name__ == "__main__":
    main()
