#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import pathlib
import re
import subprocess
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
CFG_PATH = ROOT / "gitops" / "project.yaml"


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
    tid, sid, cid = az.get("tenant_id"), az.get("subscription_id"), az.get("client_id")
    if tid and sid and cid:
        lines.extend(
            [
                f"AZURE_TENANT_ID={tid}",
                f"AZURE_SUBSCRIPTION_ID={sid}",
                f"AZURE_CLIENT_ID={cid}",
            ]
        )
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


def _chart_dir(c: dict | None = None) -> pathlib.Path:
    c = c or load_cfg()
    p = ROOT / c["helm"]["chart_path"]
    if not p.is_dir():
        print(f"::error::Missing chart dir {p}", file=sys.stderr)
        sys.exit(1)
    return p


def helm_template_all() -> None:
    chart = _chart_dir()
    for f in sorted(chart.glob("values-*.yaml")):
        if f.name == "values.yaml":
            continue
        env = f.stem.removeprefix("values-")
        subprocess.run(
            [
                "helm",
                "template",
                f"chat-app-{env}",
                str(chart),
                "-f",
                str(chart / "values.yaml"),
                "-f",
                str(f),
            ],
            check=True,
        )


def helm_template_branch(branch: str) -> None:
    chart = _chart_dir()
    overlay = chart / f"values-{branch}.yaml"
    if not overlay.is_file():
        print(f"::error::Missing {overlay}", file=sys.stderr)
        sys.exit(1)
    subprocess.run(
        [
            "helm",
            "template",
            f"chat-app-{branch}",
            str(chart),
            "-f",
            str(chart / "values.yaml"),
            "-f",
            str(overlay),
        ],
        check=True,
    )


def patch_values_image() -> None:
    b, tag = os.environ["BRANCH"], os.environ["IMAGE_TAG"]
    repo = f'{os.environ["ACR_LOGIN_SERVER"]}/{os.environ["IMAGE_NAME"]}'
    chart = ROOT / os.environ["CHART"]
    p = chart / f"values-{b}.yaml"
    data = yaml.safe_load(p.read_text()) or {}
    data.setdefault("image", {})
    data["image"]["repository"] = repo
    data["image"]["tag"] = tag
    p.write_text(yaml.dump(data, default_flow_style=False, sort_keys=False))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--github-env", action="store_true")
    ap.add_argument("--sync-files", action="store_true")
    ap.add_argument("--helm-all", action="store_true")
    ap.add_argument("--helm-branch", metavar="BRANCH")
    ap.add_argument("--patch-values-image", action="store_true")
    args = ap.parse_args()
    if not any(
        [
            args.github_env,
            args.sync_files,
            args.helm_all,
            args.helm_branch,
            args.patch_values_image,
        ]
    ):
        ap.error("pass at least one action flag")
    c = load_cfg()
    if args.github_env:
        sys.stdout.write(github_env_lines(c))
    if args.sync_files:
        sync_files(c)
    if args.helm_all:
        helm_template_all()
    if args.helm_branch:
        helm_template_branch(args.helm_branch)
    if args.patch_values_image:
        patch_values_image()


if __name__ == "__main__":
    main()
