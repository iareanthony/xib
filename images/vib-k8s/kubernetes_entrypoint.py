"""Populate VIB's image inventory from the read-only Kubernetes API."""

import os
import runpy
from pathlib import Path

import requests


def cluster_images() -> set[str]:
    token_path = Path("/var/run/secrets/kubernetes.io/serviceaccount/token")
    ca_path = Path("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
    if not token_path.exists():
        return set()

    response = requests.get(
        "https://kubernetes.default.svc/api/v1/pods",
        headers={"Authorization": f"Bearer {token_path.read_text().strip()}"},
        verify=str(ca_path),
        timeout=30,
    )
    response.raise_for_status()

    images: set[str] = set()
    for pod in response.json().get("items", []):
        spec = pod.get("spec", {})
        for key in ("initContainers", "containers"):
            for container in spec.get(key, []):
                if image := container.get("image"):
                    images.add(image)
    return images


configured = {item.strip() for item in os.getenv("ADDITIONAL_IMAGES", "").split(",") if item.strip()}
try:
    discovered = cluster_images()
    print(f"VIB Kubernetes adapter discovered {len(discovered)} image references", flush=True)
except Exception as exc:
    print(f"VIB Kubernetes discovery failed: {exc}", flush=True)
    discovered = set()

os.environ["ADDITIONAL_IMAGES"] = ",".join(sorted(configured | discovered))
runpy.run_path("/app/scanner.py", run_name="__main__")

