#!/usr/bin/env python3
"""Choose an installed iPhone simulator without storing a machine-specific UDID."""
import json
import re
import subprocess
import sys


def choose_simulator(catalog, requested=None):
    candidates = []
    for runtime, devices in catalog.get("devices", {}).items():
        match = re.search(r"\.iOS-(\d+)-(\d+)(?:-(\d+))?$", runtime)
        if not match:
            continue
        version = tuple(int(value or 0) for value in match.groups())
        if version < (17, 0, 0):
            continue
        for device in devices:
            if device.get("isAvailable") and device.get("name", "").startswith("iPhone"):
                candidates.append((version, device))
    if requested:
        for _, device in candidates:
            if device["udid"].lower() == requested.lower():
                return device["udid"]
        raise ValueError("That UDID is not an available iPhone simulator running iOS 17 or later.")
    if not candidates:
        raise ValueError("No compatible iPhone simulator found. Install an iOS 17+ simulator runtime in Xcode Settings > Components.")
    # Prefer a running iPhone, then the newest runtime, with a stable device-name tie breaker.
    candidates.sort(key=lambda item: (item[1].get("state") == "Booted", item[0], item[1]["name"], item[1]["udid"]), reverse=True)
    return candidates[0][1]["udid"]


if __name__ == "__main__":
    try:
        raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"])
        print(choose_simulator(json.loads(raw), sys.argv[1] if len(sys.argv) > 1 else None))
    except (ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
