# Building a Hybrid Multi-Agent Openclaw System from Client to Cloud
**AGENDA:**
This workshop builds a hybrid agent system in three acts:

- Start with local and cloud models running side by side.
- Add a markdown-driven routing layer that automatically chooses the right model.
- Replace it with a production-grade vLLM Semantic Router that enables:
  - PII detection and privacy-aware routing.
  - Per-skill model policies.
  - Confidence-based escalation.
- Run the complete hybrid agent system on AMD hardware.

By the end you'll have seen the same architecture at three levels of sophistication, and understand exactly what each layer adds.

---

> <span style="color:red">**Tip:**</span> Each command below includes a **Paste** button. First, click where you want the command to be pasted in the instance. Then click Paste to insert the command automatically, no typing required. Review the command, then press Enter.

---

### Your Workshop Workspace - <span style="color:red">Read This First</span>

Every step below starts with a colored band that tells you exactly where to go next. Match the band to the surface and you'll never lose your place.

### Google Chrome
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_15_01_21_181.0osuhbxypzi32hfifkyila2hsi29.png "Click to enlarge")

### Terminal Emulator
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_17_04_40_021.sk62591tezew6k8566z10w3wpb7l.png "Click to enlarge")  

### New Terminal Tab
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_19_20_22_161.2lxc8jatry4zzu3b38nnlx3a8qsw.png "Click to enlarge")

### The bands you'll see:
Switch to Browser:
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_29_381.6bj96yfp4vg8546e4w29ubravxto.png "Click to enlarge")

Switch to Terminal:
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_30_061.hchrduni450wmfg4by5tntqdkz9s.png "Click to enlarge")

Open a New Terminal Tab:
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_29_591.w3rlpml9i4zbov809ydbs9617uzt.png "Click to enlarge")

Start a New OpenClaw Session:
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_29_521.tf0s0mpgvgu1uv56h4jmbzyknk6q.png "Click to enlarge")

Inside the OpenClaw TUI:
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_30_181.611vzyf6yasvtd1gge8zs71p3out.png "Click to enlarge")

---
# Lab Setup

**Prerequisites:** Lemonade Server is running on port 13305. Your Fireworks API key is ready.

1.
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_29_591.w3rlpml9i4zbov809ydbs9617uzt.png "Click to enlarge")

Run `$HOME/hybrid-multi-agent-openclaw/start-openclaw.sh <Fireworks Api-Key>`

<button class="dark" onclick="ConsolePaste('$HOME/hybrid-multi-agent-openclaw/start-openclaw.sh <Paste Fireworks Api-Key>')" btn_type="paste" type="button">Paste Command</button>

This script:
- Onboards OpenClaw against the **Lemonade Server** on port 13305
- Registers the three Lemonade Router policies (`user.HR-Admin-Router`, `user.Benefits-Router`, `user.Finance-Router`) via `POST /api/v1/pull`
- Creates the workshop agents (`local-brain`, `cloud-brain`, `smart-router`, `hr-admin`, `benefits`, `finance`, `legal`)
- Patches the OpenClaw config with all Lemonade model entries and the Fireworks provider

2.
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_30_061.hchrduni450wmfg4by5tntqdkz9s.png "Click to enlarge")

```
openclaw tui --session workshop
```
<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">openclaw tui --session workshop</script>Paste Command</button>

![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_19_18_47_571.ore6la560tc5e6pp9bm9cqhsb6bg.png "Click to enlarge")

![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_30_181.611vzyf6yasvtd1gge8zs71p3out.png "Click to enlarge")
```
/model
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/model</script>Paste /model</button>

Select **Kimi K2.6 (Fireworks)**
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_16_00_37_081.3a1gd84hfm1bqpx523frpr8natji.png "Click to enlarge")

Introduce yourself:
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_30_181.611vzyf6yasvtd1gge8zs71p3out.png "Click to enlarge")

```
Hey! I'm <YOUR-NAME>
```


> <span style="color:red">**Tip:**</span> Each command below includes a **Paste** button. First, click where you want the command to be pasted in the instance. Then click Paste to insert the command automatically, no typing required. Review the command, then press Enter.

---
#### Lemonade Server Dashboard

![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_29_381.6bj96yfp4vg8546e4w29ubravxto.png "Click to enlarge")
 
In a new tab, go to ```http://localhost:13305```  
 
<button class="dark" onclick="ConsolePaste('http://localhost:13305')" btn_type="paste" type="button">Paste URL</button> 

Ensure the logs are enabled **View > Logs**
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_11_23_21_141.ii466aisy27r56ce01wm6irv6n2c.png "Click to enlarge")

#### Let's track the Tokenomics with a live routing monitor

![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_29_591.w3rlpml9i4zbov809ydbs9617uzt.png "Click to enlarge")

```
$HOME/hybrid-multi-agent-openclaw/tokenomics.sh
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">$HOME/hybrid-multi-agent-openclaw/tokenomics.sh</script>Paste Command</button>

![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_15_23_18_311.2w71v4bdyf3getq63asbimtbvr01.png "Click to enlarge")

| Field | Description |
|-------|-------------|
| **Routing** | Indicates which execution path handled the prompt. **LOCAL** means the request was answered entirely by a local model, while **HYBRID** means the request used both a local model and a cloud model. |
| **Cost** | The estimated cost of answering that individual prompt, calculated from the input/output token usage and the configured token pricing. |
| **Total** | The combined estimated cost of all prompts in the current session. |
| **Rates** | The token pricing used for the calculations, shown as the cost per **1 million input tokens** and **1 million output tokens** for both local and cloud models. |

For this workshop, we've defined the following token pricing model:
| Token Type | Cloud ($/1M Tokens) | Local ($/1M Tokens) |
|------------|------------------------:|------------------------:|
| **Input**  | $1.00                   | $0.10                   |
| **Output** | $5.00                   | $0.50                   |

Leave this running throughout the workshop.

---
## Act 1: Local vs Cloud Brain

Every OpenClaw agent has a configuration that defines what tools it is allowed to use.

For the Cloud Brain, we'll remove access to the filesystem and runtime tools. This means the agent can still answer questions, but it **won't be able to read local files or execute commands.**

![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_29_591.w3rlpml9i4zbov809ydbs9617uzt.png "Click to enlarge")

```
openclaw config set agents.list[2].tools \
    '{"deny":["group:fs","group:runtime"]}' --strict-json
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">openclaw config set agents.list[2].tools \ '{"deny":["group:fs","group:runtime"]}' --strict-json</script>Paste Command</button>

This updates the Cloud Brain's configuration to:

- **Deny** all filesystem tools (group:fs)
- **Deny** all runtime tools (group:runtime)

Restart the OpenClaw Gateway:

```
openclaw gateway restart
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">openclaw gateway restart</script>Paste Command</button> 

Now let's see that policy in action.

![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_29_521.tf0s0mpgvgu1uv56h4jmbzyknk6q.png "Click to enlarge")


```
openclaw tui --session workshop
```
<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">openclaw tui --session workshop</script>Paste Command</button> 


### 1a - Cloud Brain

![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_30_181.611vzyf6yasvtd1gge8zs71p3out.png "Click to enlarge")

```
/agent cloud-brain
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/agent cloud-brain</script>Paste Command</button>


```
Read the contents of ${HOME}/Downloads/projects/router-configs/data/financials.csv
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">Read the contents of ${HOME}/Downloads/projects/router-configs/data/financials.csv</script>Paste Prompt</button> 

**Tokenomics monitor shows:** ROUTING=CLOUD

The agent **refuses** - not because it can't, but because its policy says it shouldn't. 


### 1b - Local Brain - Same task. Same capability. Different boundary

![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_30_181.611vzyf6yasvtd1gge8zs71p3out.png "Click to enlarge")

```
/agent local-brain
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/agent local-brain</script>Paste Command</button>


```
Read the contents of ${HOME}/Downloads/projects/router-configs/data/financials.csv
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">Read the contents of ${HOME}/Downloads/projects/router-configs/data/financials.csv</script>Paste Prompt</button> 

You can see the local model being loaded, with **Lemonade Server**[```http://localhost:13305```] displaying logs that include metrics such as TTFT and TPS.
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_11_23_25_061.1h37w2eqzoxjefothx8oode4kdj6.png "Click to enlarge")

**Tokenomics monitor shows:** ROUTING=LOCAL

This time, the agent reads the file without any issues.

What changed?

The only difference was the agent's configuration.

- **Cloud Brain** had its filesystem and runtime tools disabled, so it couldn't access the local file.
- **Local Brain** still has those tools enabled, so it can read the file successfully.

Both agents have the same underlying capabilities, the difference is the permissions they've been given.

> **Can we automate this?**

You still had to decide which agent to use before sending the request. In a real deployment with dozens of request types, that doesn't scale.

What if the agent could decide for itself? **Act 2 fixes this.**

--- 

## Act 2 - The Smart Router: One Agent, Multiple Brains

**Scenario:** A single agent that reads every request, classifies it as LOCAL or CLOUD, and delegates to the right model - no manual switching required. 


![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_29_591.w3rlpml9i4zbov809ydbs9617uzt.png "Click to enlarge")

```
gnome-text-editor ~/.openclaw/workspace-smart-router/SOUL.md
```
<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">gnome-text-editor ~/.openclaw/workspace-smart-router/SOUL.md</script>Paste Command</button>

![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_30_181.611vzyf6yasvtd1gge8zs71p3out.png "Click to enlarge")
```
/agent smart-router
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/agent smart-router</script>Paste Command</button> 


### Simple Question → Local

```
What does a 4-year vesting schedule with a 1-year cliff mean?
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">What does a 4-year vesting schedule with a 1-year cliff mean?</script>Paste Prompt</button> 

**Expected first line:**  
Classification: LOCAL -- [Reasoning-Behind-Routing]

You can see the local model's metrics, with **Lemonade Server**[```http://localhost:13305```]  

**Tokenomics monitor:** ROUTING=LOCAL


### Code Generation → Cloud

```
Write a Python function to calculate loan interest payments.
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">Write a Python function to calculate loan interest payments.</script>Paste Prompt</button> 

**Expected first line:**  
Classification: CLOUD -- [Reasoning-Behind-Routing]

**Tokenomics monitor:** ROUTING=HYBRID

**So far:**  
 - Rules-based routing works - but it is rigid and relies on predefined decisions.
 - Real workloads are more nuanced: a request containing a name and salary should go local for privacy reasons. 
 - A financial model too complex for the local model should escalate automatically. 
 - A simple HR policy lookup shouldn't burn cloud tokens. 

That's what the **Lemonade Router** adds: **per-skill routing policies, PII detection, and semantic classification** — each tuned to the task, not a single binary rule.

---

### How the system works

**OpenClaw** is the agent runtime. It manages sessions, loads workspace files as system prompts, and calls tools on behalf of the model. Every agent in this workshop runs inside OpenClaw.

**Skills** give agents their context. Each skill injects:
- A pointer to the relevant data source (`employees.csv`, `benefits_handbook.md`, cap table CSVs)
- Output expectations (what a correct response looks like)
- Operation guidelines (e.g. soft-delete only, never overwrite existing records)

**The Lemonade Router** sits between OpenClaw and the models. Each agent uses its own `collection.router` policy. On every request it decides:
- **PII detected?** (names, emails, salaries) → stays on local AMD hardware, via regex, keyword, semantic similarity, or an LLM classifier — depending on the router
- **Simple lookup or RAG?** → local model handles it, no cloud cost
- **Complex reasoning or deep modeling?** → escalates to cloud via semantic similarity or LLM complexity classifier

System Architecture<a class="story_video" href="https://youtu.be/rFdrjZPtaKY">Click this to view the video</a>

---

## Meet the Startup Agent

Welcome to your next role: You are now **running an AI-native startup**.

Your company has:
- Employees joining every week,
- Benefits questions coming in daily,
- Financial decisions to make,
- Legal obligations to manage.

The question is no longer: "Can AI answer?"  
The question is: **Can AI answer safely, efficiently, and at the right cost?**

The agents below handle each domain - and the **vLLM Semantic Router** decides, on every request, whether the work stays on your AMD hardware or gets handed to the cloud.

#### Keep the vLLM SR and Lemonade Server dashboards open in your browser.

![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_29_381.6bj96yfp4vg8546e4w29ubravxto.png "Click to enlarge")

1. vLLM Semantic Router at ```http://localhost:8700```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">http://localhost:8700</script>Paste URL</button> 

![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_11_23_20_181.7whkmda2ujlxzqt1yv6osovj7a0h.png "Click to enlarge")
2. In a new tab, Lemonade Server at ```http://localhost:13305``` - Ensure you have the logs enabled **View > Logs**

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">http://localhost:13305</script>Paste URL</button> 

![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_11_23_21_141.ii466aisy27r56ce01wm6irv6n2c.png "Click to enlarge")


### Enter the OpenClaw session

![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_29_521.tf0s0mpgvgu1uv56h4jmbzyknk6q.png "Click to enlarge")

```
openclaw tui --session workshop2
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">openclaw tui --session workshop2</script>OpenClaw tui --session workshop2</button>

---

## 1. HR Admin Agent

**Handles:** Employee records - onboarding, salary/equity updates, role changes, and terminations  
**Router:** `user.HR-Admin-Router` - NL Router (LLM reads the request and decides local vs. cloud)  
**Data Source:** `employees.csv`

#### Agent's Goal: Update the employee database located at:

`${HOME}/Downloads/projects/router-configs/data/employees.csv`

#### First: Try it with Kimi K2.6 directly

**1.**
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_30_181.611vzyf6yasvtd1gge8zs71p3out.png "Click to enlarge")

```
/model
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/model</script>Paste /model</button>

<span style="color:red">**NOTE**:</span> The dropdown may appear in the middle of the TUI initially. It should look like this:
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_17_03_01_131.te4589bhgc9r2h2w4nxwlmlmqemp.png "Click to enlarge")
**2.** Select **Kimi K2.6 (Fireworks)** and run:

```
/skill hr-admin Onboard Jordan Lee, ML Platform Engineer, starts August 1, salary $162K, equity 0.6%, email jordan.lee@startup.ai
```

<button class="dark" onclick="ConsolePaste('/skill hr-admin Onboard Jordan Lee, ML Platform Engineer, starts August 1, salary $162K, equity 0.6%, email jordan.lee@startup.ai')" type="button">Paste Prompt</button>

**Expected Output:**
Jordan Lee is added to:

`${HOME}/Downloads/projects/router-configs/data/employees.csv`

**Verdict:** The request contained **personally identifiable information (PII)** - name, salary, equity, and email - and was sent directly to a **cloud model**. The data left the machine.

#### Now switch to the Lemonade HR Admin Router

**1.**
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_30_181.611vzyf6yasvtd1gge8zs71p3out.png "Click to enlarge")

```
/model
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/model</script>Paste /model</button>

<span style="color:red">**NOTE**:</span> The dropdown might be misplaced in the middle of the TUI but should look like this
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_17_05_22_511.pvw9899i8crm4hzcm3g93hb3qe7h.png "Click to enlarge")
**2.** Select **Lemonade HR Admin Router** (`user.HR-Admin-Router`) and run:

```
/skill hr-admin Onboard Maya Chen, Senior AI Engineer, starts July 1, salary $175K, equity 0.8%, email maya.chen@startup.ai
```

<button class="dark" onclick="ConsolePaste('/skill hr-admin Onboard Maya Chen, Senior AI Engineer, starts July 1, salary $175K, equity 0.8%, email maya.chen@startup.ai')" type="button">Paste Prompt</button>

**How the router decides:**

The `user.HR-Admin-Router` uses a **Natural Language Router** - a small `Qwen3.5-9B-NoThinking` model reads the full request and picks the destination. No keywords, no patterns. It understands that names + salary + email + equity = PII → stays local.

**Expected Router Flow:**
PII detected (name, salary, equity, email)

- `Qwen3.5-9B-NoThinking` router reads the request and selects **Local**
- Routes to **Local Qwen3.5 9B NoThinking**
- **Zero data egress** - same result, data never leaves the machine

You can see the local model being loaded, with **Lemonade Server** displaying logs that include metrics such as TTFT and TPS.
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_11_23_25_061.1h37w2eqzoxjefothx8oode4kdj6.png "Click to enlarge")

**Expected Output:**

Maya Chen is added to:

`${HOME}/Downloads/projects/router-configs/data/employees.csv`

---

## 2. Benefits Agent

**Handles:** Employee self-service questions about benefits, HR policies, and handbook content  
**Router:** `user.Benefits-Router` - Keyword + Regex Rules (deterministic, no model needed for routing)  
**Data Source:** `benefits_handbook.md`

#### Agent's Goal: Perform RAG over:

`${HOME}/Downloads/projects/router-configs/data/benefits_handbook.md`

and answer employee questions.

**1.**
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_30_181.611vzyf6yasvtd1gge8zs71p3out.png "Click to enlarge")

```
/model
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/model</script>Paste /model</button>

**2.** Select **Lemonade Benefits Router** (`user.Benefits-Router`).

#### Simple RAG question → routes Local

```
/skill benefits When does my 401(k) vesting cliff kick in?
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill benefits When does my 401(k) vesting cliff kick in?</script>Paste Prompt</button>

**How the router decides:**

The `simple-benefits-rag` rule fires: keyword `401(k)` matched + query is under 400 characters → **Local**. No model is consulted - the decision is instant and deterministic.

**Expected Router Flow:**
- `simple-benefits-rag` rule matched (keyword + max_chars)
- Routes to **Local Qwen3.5 9B NoThinking**

**Expected Output:** The agent retrieves and summarizes the handbook's 401(k) vesting policy.

#### Complex analysis question → routes Cloud

```
/skill benefits What's our parental leave policy compared to industry standard?
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill benefits What's our parental leave policy compared to industry standard?</script>Paste Prompt</button>

**How the router decides:**

The `complex-benefits-analysis` rule fires first: keyword `compared` matched - the router sees "comparison" as a signal for cloud-level reasoning before it even checks `simple-benefits-rag`.

**Expected Router Flow:**
- `complex-benefits-analysis` rule matched (`compare` keyword)
- Routes to **Cloud Kimi K2.6**

**Expected Output:** A summary of the company's parental leave policy with a comparison to common industry practices.

---

## 3. Finance Agent

**Handles:** Burn rate, equity modeling, retention analysis, budgeting, and runway forecasting  
**Router:** `user.Finance-Router` - Semantic Similarity + LLM Complexity Classifier  
**Data Sources:** `financials.csv`, `cap_table.csv`, `employees.csv`, `retention_history.csv`

#### Agent's Goal: Perform data analysis over the CSV files located in:

`${HOME}/Downloads/projects/router-configs/data/`

and answer financial questions.

**1.**
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_20_30_181.611vzyf6yasvtd1gge8zs71p3out.png "Click to enlarge")

```
/model
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/model</script>Paste /model</button>

**2.** Select **Lemonade Finance Router** (`user.Finance-Router`).

#### Simple metric lookup → routes Local

```
/skill finance What is our current burn rate?
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill finance What is our current burn rate?</script>Paste Prompt</button>

**How the router decides:**

The `finance-topic` semantic similarity classifier embeds the query and computes cosine similarity against labeled reference phrases. "What is our current burn rate" scores highest against the **`simple-lookup`** concept → **Local**.

**Expected Router Flow:**
- `finance-topic` semantic classifier → label: `simple-lookup`
- `simple-metric-lookup` rule matched
- Routes to **Local Qwen3.5 9B**

#### Complex multi-source analysis → routes Cloud

```
/skill finance One of our employees got a competitor offer in Q1 2026 and we took no action - based on what worked best historically, what intervention should we make now, and what does it cost us through year end?
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill finance One of our employees got a competitor offer in Q1 2026 and we took no action - based on what worked best historically, what intervention should we make now, and what does it cost us through year end?</script>Paste Prompt</button>

**How the router decides:**

Two classifiers evaluate this in parallel:
- **Semantic classifier** (`finance-topic`): query embeds close to the **`deep-modeling`** concept (historical analysis, intervention, cost projection)
- **LLM classifier** (`complexity`, `Qwen3.5-9B-NoThinking`): reads the request and labels it **COMPLEX** - multi-source synthesis across retention history and financials

Either classifier alone is sufficient to escalate to cloud. First match wins.

**Expected Router Flow:**
- `finance-topic` semantic classifier → label: `deep-modeling` → `deep-model-semantic` rule matched
- Routes to **Cloud Kimi K2.6**

---
## 4. **Legal Agent**

**Handles:** Regulatory research, compliance guidance, contract review, and legal Q&A  
**Data Sources:** Live web search and uploaded contracts

#### Agent's Goal: Perform web search and RAG over uploaded legal documents to answer legal and compliance questions.

**Ensure OpenClaw session is pointing to MoM (Custom Provider). If needed, switch models using `/model`**

#### Example 1
```
/skill legal What GDPR compliance and data protection regulatory requirements apply to an AI vendor under EU privacy law?
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill legal What GDPR compliance and data protection regulatory requirements apply to an AI vendor under EU privacy law?</script>Paste Prompt</button>

**Expected Router Flow:**

Legal and regulatory research

- Routes to **Cloud Kimi K2.6**

**Expected Output:** A structured summary of applicable GDPR obligations and compliance considerations.

#### Example 2
```
/skill legal Can we enforce non-compete clauses for employees in California under state contract law?

```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill legal Can we enforce non-compete clauses for employees in California under state contract law?
</script>Paste Prompt</button>

**Expected Router Flow:** Decision: `workshop_legal_cloud` → **Cloud Kimi K2.6**

---


### Fireworks API Keys

1. Sign up for Fireworks AI: https://app.fireworks.ai/signup and log in.
2. Go to https://notebooks.amd.com/codes/fireworks and enter the password **AAIOpenclaw2026** to obtain a promo code. Keep the promo code handy.
3. Click the **Credits** button:
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_22_42_031.9tvo21deifqwvjgmj7qgg4dhmidi.png "Click to enlarge")
4. Click **Redeem Promo**:
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_22_42_401.t7vxokf8wa621a6cxg7qn5ioqnyv.png "Click to enlarge")
5. Paste the promo code from step 2 into the field:
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_22_43_571.816dz696l9hvh9yfyjkt3qj2gruc.png "Click to enlarge")
You should see **$50 in credits** added to your account.
6. Generate an API key by going to: https://app.fireworks.ai/settings/users/api-keys
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_22_44_571.b49f3x7bm3pjwzc2wde4u0i4hmp8.png "Click to enlarge")
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_22_45_491.nv2h3mu96eaj6c585babmy9yxl55.png "Click to enlarge")
7. Transfer the API Key to the Instance:
   - Copy the API Key.
   - Place the cursor where you want the key to be pasted within the instance.
   - Click the dropdown next to the **Console** button and slect **Send text**:
   ![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_22_47_381.1xd315goc5w5yvtp2iw7z28vj3py.png "Click to enlarge")
   - Paste the API key into the clipboard and click **Send text**
   ![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_20_22_50_121.6e4mg6elrlt13trk4oktgt7eeork.png "Click to enlarge")
   **The API key will be pasted wherever the cursor is positioned within the instance.**