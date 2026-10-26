"""Prints the UDID of the newest available simulator whose name contains the
given text, e.g. `python3 tool/pick_simulator.py "Pro Max"` (iPhone 6.9")
or `python3 tool/pick_simulator.py "iPad Pro 13-inch"`."""
import json
import subprocess
import sys

want = sys.argv[1]
data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
best = None
for runtime, devices in data["devices"].items():
    if "iOS" not in runtime:
        continue
    version = tuple(int(x) for x in runtime.rsplit("iOS-", 1)[-1].split("-") if x.isdigit())
    for d in devices:
        if want in d["name"]:
            key = (version, d["name"])
            if best is None or key > best[0]:
                best = (key, d["udid"], d["name"])
if best is None:
    sys.exit(f"no simulator matching {want!r}")
print(best[1])
print(f"{best[2]} ({best[0][0]})", file=sys.stderr)
