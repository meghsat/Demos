#!/usr/bin/env bash
# start-openclaw.sh -- set up OpenClaw for the AAI26 Hybrid Agent workshop.
# Usage: start-openclaw.sh <Fireworks-API-Key>
#
# What this script does:
#   1. Downloads the 4 Lemonade Router JSON policies from GitHub
#   2. Downloads the workshop openclaw.json config from GitHub,
#      injects the Fireworks API key + a gateway token, and installs it
#      at ~/.openclaw/config.json
#   3. Pulls each router policy to the Lemonade Server (POST /api/v1/pull)
#   4. Writes the smart-router SOUL.md
#   5. Restarts the OpenClaw gateway
#   6. If vLLM Semantic Router is already running on :8899, wires it as a
#      backup provider automatically
set -euo pipefail

export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_RUNTIME_DIR

GITHUB_RAW="https://raw.githubusercontent.com/meghsat/Demos/main/AAI26/lemonade-router"
ROUTER_FILES="hr-admin-router.json benefits-router.json finance-router.json legal-router.json"
OC_DIR="$HOME/.openclaw"

# ---------------------------------------------------------------------------
# Fireworks API key
# ---------------------------------------------------------------------------
if [ -n "${1:-}" ]; then
  FIREWORKS_API_KEY="$1"
  if ! grep -q "^export FIREWORKS_API_KEY=" "$HOME/.bashrc" 2>/dev/null; then
    echo "export FIREWORKS_API_KEY=\"$FIREWORKS_API_KEY\"" >> "$HOME/.bashrc"
  else
    sed -i "s|^export FIREWORKS_API_KEY=.*|export FIREWORKS_API_KEY=\"$FIREWORKS_API_KEY\"|" "$HOME/.bashrc"
  fi
elif [ -n "${FIREWORKS_API_KEY:-}" ]; then
  : # already in environment
else
  FIREWORKS_API_KEY="$(sed -n 's/^export FIREWORKS_API_KEY="\(.*\)"$/\1/p' "$HOME/.bashrc" 2>/dev/null | tail -1)"
fi

[ -n "${FIREWORKS_API_KEY:-}" ] || {
  echo "Usage: $0 <Fireworks-API-Key>" >&2
  echo "  or:  export FIREWORKS_API_KEY=<key> && $0" >&2
  exit 1
}

command -v openclaw >/dev/null || { echo "ERROR: openclaw not on PATH" >&2; exit 1; }
command -v curl     >/dev/null || { echo "ERROR: curl not on PATH" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Verify Lemonade Server
# ---------------------------------------------------------------------------
curl -sf --max-time 5 "http://localhost:13305/api/v1/models" > /dev/null || {
  echo "ERROR: Lemonade Server not responding on :13305 — start it before running this script." >&2
  exit 1
}
echo "==> Lemonade Server: OK (port 13305)"

# ---------------------------------------------------------------------------
# Detect vLLM Semantic Router (optional backup)
# ---------------------------------------------------------------------------
VLLM_SR_UP=0
if curl -sf --max-time 3 "http://localhost:8899/health" > /dev/null 2>&1 || \
   curl -sf --max-time 3 "http://localhost:8899/v1/models" > /dev/null 2>&1; then
  VLLM_SR_UP=1
  echo "==> vLLM Semantic Router: detected on :8899 (wiring as backup)"
else
  echo "==> vLLM Semantic Router: not running (Lemonade Router is primary)"
fi

# ---------------------------------------------------------------------------
# Back up existing skills
# ---------------------------------------------------------------------------
SKILLS_BACKUP="$HOME/.openclaw_backup/skills"
SKILLS_BACKED_UP=0
if [ -d "$OC_DIR/skills" ]; then
  echo "==> Backing up existing skills..."
  mkdir -p "$HOME/.openclaw_backup"
  SKILLS_TMP="$HOME/.openclaw_backup/skills.tmp"
  rm -rf "$SKILLS_TMP"
  if cp -a "$OC_DIR/skills" "$SKILLS_TMP"; then
    rm -rf "$SKILLS_BACKUP"
    mv "$SKILLS_TMP" "$SKILLS_BACKUP"
    SKILLS_BACKED_UP=1
    echo "  done ($(ls "$SKILLS_BACKUP" | wc -l) skills backed up)"
  else
    echo "  WARNING: backup failed" >&2
    rm -rf "$SKILLS_TMP"
  fi
fi

# ---------------------------------------------------------------------------
# Download router JSON policies from GitHub
# ---------------------------------------------------------------------------
ROUTER_CACHE="$HOME/.openclaw_backup/lemonade-router"
mkdir -p "$ROUTER_CACHE"

echo "==> Downloading Lemonade Router policies from GitHub..."
for F in $ROUTER_FILES; do
  curl -sf --max-time 15 "$GITHUB_RAW/$F" -o "$ROUTER_CACHE/$F" \
    && echo "  $F: OK" \
    || { echo "  WARNING: failed to download $F — will use local copy if available" >&2; }
done

# ---------------------------------------------------------------------------
# Download and install openclaw.json
# ---------------------------------------------------------------------------
echo "==> Downloading workshop openclaw.json from GitHub..."
OC_CONFIG_TMP="$(mktemp)"
curl -sf --max-time 15 "$GITHUB_RAW/openclaw.json" -o "$OC_CONFIG_TMP" || {
  echo "  WARNING: GitHub download failed — using local copy from script directory" >&2
  SCRIPT_DIR="$(dirname "$(realpath "$0")")"
  LOCAL_COPY="$SCRIPT_DIR/../lemonade-router/openclaw.json"
  [ -f "$LOCAL_COPY" ] || { echo "ERROR: no openclaw.json found" >&2; exit 1; }
  cp "$LOCAL_COPY" "$OC_CONFIG_TMP"
}

# Generate a gateway token (reuse existing one if present, else generate fresh)
EXISTING_TOKEN=""
if [ -f "$OC_DIR/config.json" ]; then
  EXISTING_TOKEN="$(grep -o '"token": *"[^"]*"' "$OC_DIR/config.json" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || true)"
fi
if [ -z "$EXISTING_TOKEN" ]; then
  EXISTING_TOKEN="$(openssl rand -hex 24 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' || echo "workshop-token-$(date +%s)")"
fi

# Inject secrets into the config — replace placeholders
echo "==> Installing openclaw.json to $OC_DIR/config.json..."
mkdir -p "$OC_DIR"
OC_CONFIG_FINAL="$(mktemp)"
sed \
  -e "s|FIREWORKS_API_KEY_PLACEHOLDER|$FIREWORKS_API_KEY|g" \
  -e "s|OPENCLAW_GATEWAY_TOKEN|$EXISTING_TOKEN|g" \
  "$OC_CONFIG_TMP" > "$OC_CONFIG_FINAL"
rm -f "$OC_CONFIG_TMP"
cp "$OC_CONFIG_FINAL" "$OC_DIR/config.json"
echo "  done"

# If vLLM SR is NOT running, strip the semanticrouter provider block so
# OpenClaw doesn't warn about an unreachable provider on startup.
# We do a simple in-place edit — the block is a well-known string in our template.
if [ "$VLLM_SR_UP" = "0" ]; then
  # Remove the semanticrouter provider entry and its models/defaults entry
  # using Python (available on all Ubuntu workshop machines) for safe JSON surgery
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$OC_DIR/config.json" <<'PY'
import sys, json
path = sys.argv[1]
with open(path) as f:
    cfg = json.load(f)
# Remove from providers
cfg.get("models", {}).get("providers", {}).pop("semanticrouter", None)
# Remove from agent defaults models map
cfg.get("agents", {}).get("defaults", {}).get("models", {}).pop("semanticrouter/MoM", None)
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
PY
    echo "  vLLM SR not detected — removed semanticrouter from config"
  fi
fi

# ---------------------------------------------------------------------------
# Onboard OpenClaw (registers the daemon; config.json already in place)
# ---------------------------------------------------------------------------
echo "==> Onboarding OpenClaw..."
openclaw onboard --non-interactive \
  --mode local --auth-choice custom-api-key \
  --custom-provider-id lemonade \
  --custom-base-url "http://localhost:13305/v1" \
  --custom-model-id "Qwen3.5-9B-NoThinking" \
  --custom-compatibility openai --custom-image-input \
  --secret-input-mode plaintext \
  --gateway-port 18789 --gateway-bind loopback --gateway-auth token \
  --skip-health --accept-risk --install-daemon

# Restore our config — openclaw onboard may have overwritten it
cp "$OC_CONFIG_FINAL" "$OC_DIR/config.json"
rm -f "$OC_CONFIG_FINAL"

echo "==> Restarting gateway with workshop config..."
openclaw gateway restart

# ---------------------------------------------------------------------------
# Pull Lemonade Router policies to Lemonade Server
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
echo "==> Registering Lemonade Router policies with Lemonade Server..."
for F in $ROUTER_FILES; do
  # Prefer freshly downloaded copy, fall back to local repo copy
  FPATH="$ROUTER_CACHE/$F"
  if [ ! -f "$FPATH" ]; then
    FPATH="$SCRIPT_DIR/../lemonade-router/$F"
  fi
  if [ -f "$FPATH" ]; then
    RESULT=$(curl -s -X POST "http://localhost:13305/api/v1/pull" \
      -H "Content-Type: application/json" \
      --data-binary "@$FPATH" 2>&1)
    MODEL=$(echo "$RESULT" | grep -o '"model_name":"[^"]*"' | sed 's/"model_name":"//;s/"//')
    STATUS=$(echo "$RESULT" | grep -o '"status":"[^"]*"' | sed 's/"status":"//;s/"//')
    if [ "$STATUS" = "success" ]; then
      echo "  $F → $MODEL: registered"
    else
      echo "  WARNING: $F failed: $RESULT" >&2
    fi
  else
    echo "  WARNING: $F not found locally or in cache — skipping" >&2
  fi
done

# ---------------------------------------------------------------------------
# Smart-router SOUL.md
# ---------------------------------------------------------------------------
echo "==> Writing smart-router SOUL.md..."
mkdir -p "$OC_DIR/workspace-smart-router"
SMART_SOUL="$OC_DIR/workspace-smart-router/SOUL.md"
EXISTING_SOUL=""
[ -f "$SMART_SOUL" ] && EXISTING_SOUL=$(cat "$SMART_SOUL")

cat > "$SMART_SOUL" << 'ROUTING'
FORMAT RULE -- MANDATORY, NO EXCEPTIONS:
Every single response MUST begin with exactly one of these two lines:
  Classification: LOCAL -- [reason]
  Classification: CLOUD -- [reason]. Delegating to kimi-k2p6.
Never skip this line. Even for a one-word answer.

---

## Routing Rules

### CLOUD -- escalate if the request matches ANY of these:
- write / create / implement / generate / build / design + code or script
- fix / debug / refactor / optimize + code or function
- explain why a test or build failed, explain a traceback or error
- root cause analysis, N+1, latency, performance bottleneck
- any multi-step reasoning about why something is wrong

### LOCAL -- stay local if:
- run a command, return output
- parse JSON / logs / CSV, extract a field
- read a file, summarize a document
- any task with one deterministic mechanical answer

### Escalation protocol (CLOUD only):
1. First line: Classification: CLOUD -- [reason]. Delegating to kimi-k2p6.
2. Call sessions_spawn with model="fireworks/accounts/fireworks/models/kimi-k2p6"
3. Call sessions_yield to return the result.

**Default is LOCAL.**

---

# Who You Are
You are smart-router: handles simple tasks locally, delegates complex tasks to cloud.
Every response starts with the Classification line.
ROUTING

if [ -n "$EXISTING_SOUL" ]; then
  printf '\n---\n\n%s\n' "$EXISTING_SOUL" >> "$SMART_SOUL"
fi
echo "  SOUL.md written ($(wc -l < "$SMART_SOUL") lines)"

# ---------------------------------------------------------------------------
# Restart gateway to pick up SOUL.md
# ---------------------------------------------------------------------------
echo "==> Restarting gateway..."
openclaw gateway restart

# ---------------------------------------------------------------------------
# Truncate workspace history files
# ---------------------------------------------------------------------------
echo "==> Clearing workspace history..."
for WS in "$OC_DIR/workspace" "$OC_DIR/workspace-local-brain" "$OC_DIR/workspace-cloud-brain" "$OC_DIR/workspace-smart-router"; do
  [ -d "$WS" ] || continue
  find "$WS" -maxdepth 1 -type f ! -name "SOUL.md" | while read -r f; do : > "$f"; done
done
echo "  done"

# ---------------------------------------------------------------------------
# Restore skills
# ---------------------------------------------------------------------------
if [ "$SKILLS_BACKED_UP" = "1" ] && [ -d "$SKILLS_BACKUP" ]; then
  echo "==> Restoring skills..."
  rm -rf "$OC_DIR/skills"
  if cp -a "$SKILLS_BACKUP" "$OC_DIR/skills"; then
    echo "  done ($(ls "$OC_DIR/skills" | wc -l) skills restored)"
  else
    echo "  ERROR: restore failed — check $SKILLS_BACKUP manually" >&2
  fi
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
cat <<'EOF_DONE'

OpenClaw is configured and ready.
  Status : openclaw gateway status --deep
  Try it : openclaw tui --session workshop

Lemonade Router policies registered:
  user.HR-Admin-Router   -- NL Router (LLM decides local vs cloud)
  user.Benefits-Router   -- Keywords + Regex (deterministic, instant)
  user.Finance-Router    -- Semantic Similarity + LLM Complexity Classifier
  user.Legal-Router      -- Cloud (Kimi K2.6 via Lemonade)

Workshop agents (from openclaw.json):
  Act 1 + 2:
    /agent local-brain   -- Qwen3.6 35B on AMD hardware
    /agent cloud-brain   -- Kimi K2.6 on Fireworks (no fs/runtime tools)
    /agent smart-router  -- SOUL.md rules-based routing

  Act 3:
    /agent hr-admin      -- user.HR-Admin-Router
    /agent benefits      -- user.Benefits-Router
    /agent finance       -- user.Finance-Router
    /agent legal         -- user.Legal-Router
EOF_DONE

if [ "$VLLM_SR_UP" = "1" ]; then
  echo ""
  echo "  Backup: vLLM Semantic Router wired on :8899"
  echo "    /model → select 'MoM — vLLM Semantic Router (backup)'"
fi
