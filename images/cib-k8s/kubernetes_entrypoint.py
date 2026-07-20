"""Populate CIB's image inventory from the read-only Kubernetes API."""

import os
import runpy
from pathlib import Path

import requests


def cluster_images() -> set[str]:
    root = Path("/var/run/secrets/kubernetes.io/serviceaccount")
    token = (root / "token").read_text().strip()
    response = requests.get(
        "https://kubernetes.default.svc/api/v1/pods",
        headers={"Authorization": f"Bearer {token}"},
        verify=str(root / "ca.crt"),
        timeout=30,
    )
    response.raise_for_status()
    return {
        container["image"]
        for pod in response.json().get("items", [])
        for key in ("initContainers", "containers")
        for container in pod.get("spec", {}).get(key, [])
        if container.get("image")
    }


configured = {item.strip() for item in os.getenv("ADDITIONAL_IMAGES", "").split(",") if item.strip()}
try:
    discovered = cluster_images()
    print(f"CIB Kubernetes adapter discovered {len(discovered)} image references", flush=True)
except Exception as exc:
    print(f"CIB Kubernetes discovery failed: {exc}", flush=True)
    discovered = set()

os.environ["ADDITIONAL_IMAGES"] = ",".join(sorted(configured | discovered))
runpy.run_path("/app/checker.py", run_name="__main__")

