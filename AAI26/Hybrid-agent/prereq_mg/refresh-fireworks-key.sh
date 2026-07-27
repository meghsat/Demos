#!/usr/bin/env bash
# refresh-fireworks-key.sh — swap the Fireworks API key in the existing
# OpenClaw config and restart the gateway.
#
# Usage:
#   export FIREWORKS_API_KEY=fw_xxxx
#   ./refresh-fireworks-key.sh
set -euo pipefail

export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_RUNTIME_DIR

OC_CONFIG="$HOME/.openclaw/openclaw.json"

[ -n "${FIREWORKS_API_KEY:-}" ] || {
  echo "ERROR: FIREWORKS_API_KEY is not set." >&2
  echo "  Run: export FIREWORKS_API_KEY=<key> && $0" >&2
  exit 1
}

[ -f "$OC_CONFIG" ] || {
  echo "ERROR: $OC_CONFIG not found — run start-openclaw.sh first." >&2
  exit 1
}

command -v openclaw >/dev/null || { echo "ERROR: openclaw not on PATH" >&2; exit 1; }

echo "==> Updating Fireworks API key in $OC_CONFIG..."
python3 - "$OC_CONFIG" "$FIREWORKS_API_KEY" <<'PY'
import sys, json
path, key = sys.argv[1], sys.argv[2]
with open(path) as f:
    cfg = json.load(f)
updated = 0
for pid, pdata in cfg.get("models", {}).get("providers", {}).items():
    if "fireworks" in pid.lower() or "fireworks" in pdata.get("base_url", "").lower():
        pdata["api_key"] = key
        updated += 1
if updated == 0:
    print("WARNING: no fireworks provider entry found in config", file=sys.stderr)
    sys.exit(1)
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
print(f"  updated {updated} provider entry(s)")
PY

echo "==> Restarting OpenClaw gateway..."
openclaw gateway restart
echo "Done."
