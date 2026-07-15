# Hybrid Agent Workshop

> **Before you start:** The setup script has already run. All agents are pre-configured — no installation needed.
> Open two terminals: one for OpenClaw, one for the live routing monitor.

---

## Live Routing Monitor (keep this running)

In your **second terminal**, start the gateway log monitor. It shows every model call in real time:

```
journalctl --user -f -u openclaw-gateway.service | grep --line-buffered "model-fetch"
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">journalctl --user -f -u openclaw-gateway.service | grep --line-buffered "model-fetch"</script>Paste Command</button>

- `url=http://localhost:13305` means the request stayed on AMD hardware
- `url=https://api.fireworks.ai` means it went to the Fireworks cloud API

Leave this running throughout both acts.

---

## Act 1 — Local Brain vs Cloud Brain

**What this shows:** The same task sent to two different agents. One runs entirely on the AMD GPU in this machine — zero data egress, zero cost. The other calls the Fireworks cloud API.

Start an OpenClaw session:

```
openclaw tui --session workshop
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">openclaw tui --session workshop</script>Paste Command</button>

---

### Ask the cloud brain

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

**Monitor shows:** `provider=fireworks  url=https://api.fireworks.ai` — every token costs money.

---

### Ask the local brain

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

**Monitor shows:** `provider=lemonade  url=http://localhost:13305` — same task, AMD GPU, zero API cost.

**The problem:** You had to know in advance which agent to use. Act 2 fixes this.

---

## Act 2 — Agentic Routing

**What this shows:** A single agent that reads every request, classifies it as LOCAL or CLOUD on its first line, and automatically delegates to the right model — no manual switching required.

**How it works:** The smart-router agent has a `SOUL.md` file injected as its system prompt on every turn. The local Qwen model reads the routing rules and outputs `Classification: LOCAL` or `Classification: CLOUD`. If CLOUD, it calls `sessions_spawn` to spin up a kimi-k2p6 sub-session on Fireworks and hands off the task.

**The routing policy is a markdown file. No ML classifier. No retraining. Edit the file, change the policy.**

Switch to smart-router:

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

**First line of response:** `Classification: LOCAL -- single deterministic answer`

**Monitor:** one line — `provider=lemonade`. Stayed on AMD hardware.

---

### CLOUD example

```
Write a Python retry decorator with exponential backoff and jitter
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">Write a Python retry decorator with exponential backoff and jitter</script>Paste Prompt</button>

**First line of response:** `Classification: CLOUD -- code generation. Delegating to kimi-k2p6.`

**Monitor:** two lines — `provider=lemonade` (Qwen classifies), then `provider=fireworks` (kimi answers).
