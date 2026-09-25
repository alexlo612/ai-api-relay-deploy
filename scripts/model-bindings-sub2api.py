#!/usr/bin/env python3
"""Check or apply Messages-dispatch aliases on a Sub2API OpenAI group."""

import argparse
import json
import os
import stat
import subprocess
from pathlib import Path
from urllib.request import Request, urlopen


def app_url():
    container_id = subprocess.check_output(
        ["docker", "compose", "-f", str(Path(__file__).resolve().parents[1] / "compose.yaml"),
         "ps", "-q", "sub2api"],
        text=True,
    ).strip()
    if not container_id:
        raise RuntimeError("Sub2API container is not running")
    container = json.loads(subprocess.check_output(["docker", "inspect", container_id]))[0]
    networks = container["NetworkSettings"]["Networks"]
    edge = next((entry for name, entry in networks.items() if name.endswith("_edge")), None)
    if not edge or not edge.get("IPAddress"):
        raise RuntimeError("Sub2API edge-network address is unavailable")
    return f"http://{edge['IPAddress']}:8080"


def group_request(url, key, method="GET", payload=None):
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"x-api-key": key}
    if data is not None:
        headers["Content-Type"] = "application/json"
    with urlopen(Request(url, data=data, headers=headers, method=method), timeout=15) as response:
        result = json.load(response)
    if not isinstance(result.get("data"), dict):
        raise RuntimeError("Unexpected Sub2API group response")
    return result["data"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--key-file", required=True, type=Path)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    config = json.loads(args.config.read_text())
    aliases = config["aliases"]
    legacy = config["legacy_aliases"]
    key_mode = stat.S_IMODE(args.key_file.stat().st_mode)
    if key_mode != 0o600 or args.key_file.stat().st_uid != os.getuid():
        raise RuntimeError("Sub2API admin key file must be owned by this user and mode 0600")
    key = args.key_file.read_text().strip()
    if not key:
        raise RuntimeError("Sub2API admin key file is empty")

    url = f"{app_url()}/api/v1/admin/groups/{config['sub2api_group_id']}"
    group = group_request(url, key)
    if group.get("platform") != "openai" or not group.get("allow_messages_dispatch"):
        raise RuntimeError("Target group is not an active OpenAI Messages-dispatch group")
    current = group.get("messages_dispatch_model_config") or {}
    if current.get("opus_mapped_model") != aliases["claude-opus-5-5"]:
        raise RuntimeError("Opus family mapping differs from the desired GPT-6 target")
    if current.get("sonnet_mapped_model") != aliases["claude-sonnet-5"]:
        raise RuntimeError("Sonnet family mapping differs from the desired GPT-6 target")
    exact = current.get("exact_model_mappings") or {}
    for alias, target in aliases.items():
        if alias in exact and exact[alias] != target:
            raise RuntimeError(f"Existing exact mapping for {alias} conflicts with the desired target")
    for alias, target in legacy.items():
        if alias in exact and exact[alias] != target:
            raise RuntimeError(f"Legacy exact mapping for {alias} changed unexpectedly")

    changes = {alias: target for alias, target in aliases.items() if exact.get(alias) != target}
    removals = set(exact).intersection(legacy)
    if not changes and not removals:
        print("Sub2API exact mappings already match the desired aliases.")
        return
    print("Sub2API exact mappings to add: " +
          ", ".join(f"{alias} -> {target}" for alias, target in changes.items()) +
          "; to remove: " + ", ".join(sorted(removals)))
    if not args.apply:
        return

    updated = dict(current)
    updated["exact_model_mappings"] = {
        **{alias: target for alias, target in exact.items() if alias not in legacy},
        **changes,
    }
    group_request(url, key, "PUT", {"messages_dispatch_model_config": updated})
    saved = group_request(url, key).get("messages_dispatch_model_config") or {}
    if any(saved.get("exact_model_mappings", {}).get(alias) != target
           for alias, target in aliases.items()) or any(
               alias in saved.get("exact_model_mappings", {}) for alias in legacy):
        raise RuntimeError("Sub2API did not persist the expected exact mappings")
    print("Sub2API exact mappings verified.")


if __name__ == "__main__":
    main()
