# Hybrid Agent Routing — Add-on Guide

> This section adds two new acts to the existing workshop:
> **Act 1** shows manual local vs cloud switching. **Act 2** shows automatic SOUL.md routing.
> The existing semantic router exercises are unchanged.

---

## One-Time Setup

> Run these commands once in your terminal before starting the acts below.
> They use the model names already configured in your `openclaw.json` — no new installation required.

### Step 1 — Create the three agents

Run all three commands one at a time.

**local-brain** (runs locally on AMD hardware):

```
openclaw agents add local-brain --model "lemonade/Qwen3.6-35B-A3B-NoThinking" --workspace ~/.openclaw/workspace-local-brain --non-interactive --json
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">openclaw agents add local-brain --model "lemonade/Qwen3.6-35B-A3B-NoThinking" --workspace ~/.openclaw/workspace-local-brain --non-interactive --json</script>Paste Command</button>

**cloud-brain** (calls Fireworks API):

```
openclaw agents add cloud-brain --model "fireworks/accounts/fireworks/models/kimi-k2p6" --workspace ~/.openclaw/workspace-cloud-brain --non-interactive --json
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">openclaw agents add cloud-brain --model "fireworks/accounts/fireworks/models/kimi-k2p6" --workspace ~/.openclaw/workspace-cloud-brain --non-interactive --json</script>Paste Command</button>

**smart-router** (local model that auto-routes):

```
openclaw agents add smart-router --model "lemonade/Qwen3.6-35B-A3B-NoThinking" --workspace ~/.openclaw/workspace-smart-router --non-interactive --json
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">openclaw agents add smart-router --model "lemonade/Qwen3.6-35B-A3B-NoThinking" --workspace ~/.openclaw/workspace-smart-router --non-interactive --json</script>Paste Command</button>

Each command prints a JSON summary when it succeeds. No JSON output means an error occurred.

> **Note:** You may see a plugin warning line before the JSON (`plugins.allow is empty...`). This is harmless — ignore it and look for the JSON block that follows.

**Remove the onboarding file from each agent workspace.** OpenClaw seeds a `BOOTSTRAP.md` that triggers a "hello, who are you?" introduction on first use. Delete it from all three:

```
rm -f ~/.openclaw/workspace-local-brain/BOOTSTRAP.md ~/.openclaw/workspace-cloud-brain/BOOTSTRAP.md ~/.openclaw/workspace-smart-router/BOOTSTRAP.md
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">rm -f ~/.openclaw/workspace-local-brain/BOOTSTRAP.md ~/.openclaw/workspace-cloud-brain/BOOTSTRAP.md ~/.openclaw/workspace-smart-router/BOOTSTRAP.md</script>Paste Command</button>

Verify all three were created:

```
openclaw agents list
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">openclaw agents list</script>Paste Command</button>

You should see: `main`, `local-brain`, `cloud-brain`, `smart-router`.

---

### Step 2 — Write the routing rules (SOUL.md) for smart-router

This single command writes the routing policy that smart-router will follow on every turn:

```
mkdir -p ~/.openclaw/workspace-smart-router && cat > ~/.openclaw/workspace-smart-router/SOUL.md << 'SOUL'
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
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">mkdir -p ~/.openclaw/workspace-smart-router && cat > ~/.openclaw/workspace-smart-router/SOUL.md << 'SOUL'
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
SOUL</script>Paste Command</button>

Verify it was written:

```
wc -l ~/.openclaw/workspace-smart-router/SOUL.md
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">wc -l ~/.openclaw/workspace-smart-router/SOUL.md</script>Paste Command</button>

You should see `50` or more lines.

---

### Step 3 — Open a live routing monitor (optional, recommended for developers)

In a **second terminal**, run this before starting the acts. It shows every model call the gateway makes in real time — local stays on `localhost:13305`, cloud goes to `api.fireworks.ai`:

```
journalctl --user -f -u openclaw-gateway.service | grep --line-buffered "model-fetch"
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">journalctl --user -f -u openclaw-gateway.service | grep --line-buffered "model-fetch"</script>Paste Command</button>

Leave this running. When a LOCAL prompt fires you will see `url=http://localhost:13305`. When a CLOUD prompt fires you will see `url=https://api.fireworks.ai`.

---

## Act 1 — Local Brain vs Cloud Brain

> **What this shows:** The same task sent to two different agents — one running entirely on AMD hardware, one calling the Fireworks cloud API. You manually choose which agent handles the request.

### Start an OpenClaw session

```
openclaw tui --session hybrid-act1
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">openclaw tui --session hybrid-act1</script>Paste Command</button>

---

### 1a — Ask the cloud brain

Switch to the cloud agent:

```
/agent cloud-brain
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/agent cloud-brain</script>Paste Command</button>

Send a task:

```
Write a Python function that detects N+1 SQL queries in a SQLAlchemy ORM codebase
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">Write a Python function that detects N+1 SQL queries in a SQLAlchemy ORM codebase</script>Paste Prompt</button>

**What to observe:** The gateway monitor shows `url=https://api.fireworks.ai`. The response comes from Kimi K2.6. Every token cost money.

---

### 1b — Ask the local brain the same task

Switch to the local agent:

```
/agent local-brain
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/agent local-brain</script>Paste Command</button>

Send the same task:

```
Write a Python function that detects N+1 SQL queries in a SQLAlchemy ORM codebase
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">Write a Python function that detects N+1 SQL queries in a SQLAlchemy ORM codebase</script>Paste Prompt</button>

**What to observe:** The gateway monitor shows `url=http://localhost:13305`. The response comes from Qwen running on the AMD GPU in this machine. Zero data egress, zero API cost.

**The problem with manual switching:** You had to know in advance which agent to use. Act 2 solves this.

---

## Act 2 — Agentic Routing

> **What this shows:** A single agent that reads the request, classifies it as LOCAL or CLOUD in its first line, and automatically delegates to the right model — no manual switching required.

### How it works

The smart-router agent has a `SOUL.md` file in its workspace. The gateway injects this as a system prompt on every turn. The local Qwen model reads the routing rules and produces `Classification: LOCAL` or `Classification: CLOUD` as its first line. If CLOUD, it calls `sessions_spawn` to spin up a kimi-k2p6 sub-session on Fireworks and hands off the task.

**The routing policy is a markdown file. No ML classifier. No retraining. Edit the file to change the policy.**

---

### Switch to smart-router

```
/agent smart-router
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/agent smart-router</script>Paste Command</button>

---

### LOCAL example

```
What does exit code 137 mean on Linux?
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">What does exit code 137 mean on Linux?</script>Paste Prompt</button>

**Expected first line:** `Classification: LOCAL -- single deterministic answer`

**Gateway monitor:** one line — `provider=lemonade`. Stayed on AMD hardware.

---

### CLOUD example

```
Write a Python retry decorator with exponential backoff and jitter
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">Write a Python retry decorator with exponential backoff and jitter</script>Paste Prompt</button>

**Expected first line:** `Classification: CLOUD -- code generation. Delegating to kimi-k2p6.`

**Gateway monitor:** two lines — first `provider=lemonade` (Qwen classifying), then `provider=fireworks` (kimi doing the work).

---

*The existing workshop exercises continue below.*

---
