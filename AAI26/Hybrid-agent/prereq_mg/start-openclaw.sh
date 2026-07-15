#!/usr/bin/env bash
# start-openclaw.sh -- onboard OpenClaw against the vLLM Semantic Router
# (non-interactive) and apply the workshop config patch. Run AFTER
# start-vllm-sr.sh: the router must be serving on :8899 and the Fireworks
# key must be in the environment (start-vllm-sr.sh exports + persists it
# to ~/.bashrc as FIREWORKS_API_KEY -- no argument needed here).
set -euo pipefail

export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_RUNTIME_DIR

# start-vllm-sr.sh's export can't reach a shell that was already open, so
# fall back to the line it persisted in ~/.bashrc.
if [ -z "${FIREWORKS_API_KEY:-}" ]; then
  FIREWORKS_API_KEY="$(sed -n 's/^export FIREWORKS_API_KEY="\(.*\)"$/\1/p' "$HOME/.bashrc" | tail -1)"
fi
[ -n "$FIREWORKS_API_KEY" ] || {
  echo "FIREWORKS_API_KEY not set -- run start-vllm-sr.sh <key> first (it persists the key)," >&2
  echo "or: export FIREWORKS_API_KEY=<key>" >&2
  exit 1
}

command -v openclaw >/dev/null || { echo "openclaw not on PATH" >&2; exit 1; }

echo "==> Onboarding OpenClaw against the Semantic Router (:8899)..."
openclaw onboard --non-interactive \
  --mode local --auth-choice custom-api-key \
  --custom-provider-id semanticrouter \
  --custom-base-url "http://localhost:8899/v1" \
  --custom-model-id "MoM" \
  --custom-compatibility openai --custom-image-input \
  --secret-input-mode plaintext \
  --gateway-port 18789 --gateway-bind loopback --gateway-auth token \
  --skip-health --accept-risk --install-daemon

echo "==> Applying workshop config patch..."
PATCH=/tmp/oc-patch.json5
rm -f "$PATCH"; touch "$PATCH"; chmod 600 "$PATCH"
cat > "$PATCH" <<EOF_OC_PATCH
{
  agents: {
    defaults: {
      contextInjection: "never",
      models: {
        "semanticrouter/MoM": {},
        "lemonade/Qwen3.6-35B-A3B-NoThinking": {},
        "lemonade/Qwen3.5-9B-NoThinking": {},
        "fireworks/accounts/fireworks/models/kimi-k2p6": {}
      }
    }
  },
  gateway: {
    controlUi: { allowInsecureAuth: true },
    nodes: { denyCommands: ["camera.snap","camera.clip","screen.record","contacts.add","calendar.add","reminders.add","sms.send","sms.search"] }
  },
  session: { dmScope: "per-channel-peer" },
  tools: { profile: "coding" },
  models: {
    mode: "merge",
    providers: {
      semanticrouter: {
        models: [{ id: "MoM", name: "MoM (Custom Provider)", contextWindow: 262000, maxTokens: 32768,
          input: ["text","image"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, reasoning: false }]
      },
      lemonade: {
        baseUrl: "http://localhost:13305/v1", api: "openai-completions",
        models: [
          { id: "Qwen3.6-35B-A3B-NoThinking", name: "Qwen3.6 35B A3B (NoThinking)", contextWindow: 262000, maxTokens: 32768,
            input: ["text","image"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, reasoning: false },
          { id: "Qwen3.5-9B-NoThinking", name: "Qwen3.5 9B (NoThinking)", contextWindow: 262000, maxTokens: 32768,
            input: ["text","image"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, reasoning: false }
        ]
      },
      fireworks: {
        baseUrl: "https://api.fireworks.ai/inference/v1", api: "openai-completions", auth: "api-key",
        apiKey: "$FIREWORKS_API_KEY",
        models: [{ id: "accounts/fireworks/models/kimi-k2p6", name: "Kimi K2 (Fireworks)", contextWindow: 262000, maxTokens: 32768,
          input: ["text"], cost: { input: 3.00, output: 9.00, cacheRead: 0, cacheWrite: 0 }, reasoning: false }]
      }
    }
  }
}
EOF_OC_PATCH

openclaw config patch --file "$PATCH"
rm -f "$PATCH"

echo "==> Restarting the gateway to pick up the new config..."
openclaw gateway restart

# ---------------------------------------------------------------------------
# Hybrid routing agents (Act 1 + Act 2 of the workshop)
# All three use model IDs already registered in the config patch above.
# Idempotent: silently skips if the agent already exists.
# ---------------------------------------------------------------------------
echo "==> Creating hybrid routing agents..."

OC_DIR="$HOME/.openclaw"

openclaw agents add local-brain \
  --model "lemonade/Qwen3.6-35B-A3B-NoThinking" \
  --workspace "$OC_DIR/workspace-local-brain" \
  --non-interactive --json 2>/dev/null \
  && echo "  local-brain: created" \
  || echo "  local-brain: already exists"

openclaw agents add cloud-brain \
  --model "fireworks/accounts/fireworks/models/kimi-k2p6" \
  --workspace "$OC_DIR/workspace-cloud-brain" \
  --non-interactive --json 2>/dev/null \
  && echo "  cloud-brain: created" \
  || echo "  cloud-brain: already exists"

openclaw agents add smart-router \
  --model "lemonade/Qwen3.6-35B-A3B-NoThinking" \
  --workspace "$OC_DIR/workspace-smart-router" \
  --non-interactive --json 2>/dev/null \
  && echo "  smart-router: created" \
  || echo "  smart-router: already exists"

echo "==> Removing onboarding files from agent workspaces..."
rm -f \
  "$OC_DIR/workspace-local-brain/BOOTSTRAP.md" \
  "$OC_DIR/workspace-cloud-brain/BOOTSTRAP.md" \
  "$OC_DIR/workspace-smart-router/BOOTSTRAP.md"

echo "==> Writing smart-router routing rules (SOUL.md)..."
mkdir -p "$OC_DIR/workspace-smart-router"
cat > "$OC_DIR/workspace-smart-router/SOUL.md" << 'SOUL'
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
- explain why a test or build failed
- explain a traceback, exception, or error message
- root cause analysis of any kind
- N+1, latency, performance bottleneck
- any multi-step reasoning about why something is wrong

### LOCAL -- stay local if:

- run a command, return output
- parse JSON / logs / CSV, extract a field
- install a package, check exit code
- read a file, summarize a document
- any task with one deterministic mechanical answer

### Examples (follow this exact format):

User: Run ls -la /tmp
Classification: LOCAL -- shell command, deterministic output
[answer here]

User: Parse this JSON and extract version: {"v": "1.2"}
Classification: LOCAL -- JSON field extraction, deterministic
1.2

User: Write a retry decorator with exponential backoff
Classification: CLOUD -- code generation. Delegating to kimi-k2p6.
[sessions_spawn called]

### Escalation protocol (CLOUD only):

1. First line: Classification: CLOUD -- [reason]. Delegating to kimi-k2p6.
2. Call sessions_spawn with model=fireworks/accounts/fireworks/models/kimi-k2p6
3. Use sessions_yield to return the result

**Default is LOCAL. CLOUD is triggered only by the explicit list above.**

---

# Who You Are

You are smart-router: a hybrid agent that handles simple tasks locally
and delegates complex tasks to cloud when needed.
Be concise. Every response starts with the Classification line.
SOUL

echo "  smart-router SOUL.md: written ($(wc -l < "$OC_DIR/workspace-smart-router/SOUL.md") lines)"

echo "==> Restarting the gateway to pick up agents and SOUL.md..."
openclaw gateway restart

cat <<'EOF_DONE'

OpenClaw is onboarded and configured.
  Status : openclaw gateway status --deep
  Try it : openclaw tui --session test1

Hybrid routing agents ready:
  /agent local-brain   -- Qwen3.6 35B on AMD hardware (Act 1)
  /agent cloud-brain   -- Kimi K2.6 on Fireworks (Act 1)
  /agent smart-router  -- auto-routes LOCAL/CLOUD via SOUL.md (Act 2)
EOF_DONE
