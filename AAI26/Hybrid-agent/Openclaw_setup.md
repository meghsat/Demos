# Openclaw Setup

## Install

```bash
git clone https://github.com/meghsat/openclaw
cd openclaw
git checkout feat/openclaw-semantic-router
pnpm install
pnpm build && pnpm ui:build
ln -sf "$(pwd)/openclaw.mjs" ~/.local/bin/openclaw
```

## Onboard

```bash
openclaw onboard --install-daemon
```

## Configure Backend

### Lemonade

| Field | Value |
|---|---|
| Model/auth provider | Custom Provider |
| API Base URL | `http://127.0.0.1:13305/api/v1` |
| API Key | `lemonade` |
| Endpoint compatibility | OpenAI-compatible |
| Model ID | `Qwen3.6-35B-A3B-GGUF` |
| Endpoint ID | `lemonade` |

### Semantic Router

| Field | Value |
|---|---|
| Model/auth provider | Custom Provider |
| API Base URL | `http://localhost:8899/v1` |
| API Key | *(leave blank)* |
| Endpoint compatibility | OpenAI-compatible |
| Model ID | `MoM` |
| Endpoint ID | `SemanticRouter` |

## Launch TUI

```bash
openclaw tui

# Start a named session
openclaw tui --session test1
```

---

## Custom Modifications

1. Added header detection for vLLM-SR responses — ensures Openclaw selects the correct model per request when the Semantic Router is the backend.
2. Added routing decision display in the TUI.
3. Added per-model token consumption tracking.
