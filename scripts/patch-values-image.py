#!/usr/bin/env python3
import os
import pathlib

import yaml

branch = os.environ["BRANCH"]
tag = os.environ["IMAGE_TAG"]
repo = f'{os.environ["ACR_LOGIN_SERVER"]}/{os.environ["IMAGE_NAME"]}'
chart = os.environ["CHART"]
path = pathlib.Path(chart) / f"values-{branch}.yaml"
data = yaml.safe_load(path.read_text()) or {}
data.setdefault("image", {})
data["image"]["repository"] = repo
data["image"]["tag"] = tag
path.write_text(yaml.dump(data, default_flow_style=False, sort_keys=False))
