# Hybrid Agent Workshop

> **Tip:** Each command below includes a **Paste** button. Click it to paste the command directly into OpenClaw's terminal, no typing required. Review the command, then press **Enter**.

---

## Before You Start - Open the live routing monitor

In a **second terminal**, start the gateway log monitor. It shows every model call in real time:

```
journalctl --user -f -u openclaw-gateway.service | grep --line-buffered "model-fetch"
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">journalctl --user -f -u openclaw-gateway.service | grep --line-buffered "model-fetch"</script>Paste Command</button>

- `url=http://localhost:13305` - request stayed on AMD hardware
- `url=https://api.fireworks.ai` - request went to the cloud

Leave this running throughout the workshop.

---

## Act 1 - Local Brain vs Cloud Brain

**What this shows:** The same task routed to two different backends. You pick manually. One runs entirely on the AMD GPU in this machine - zero data egress, zero cost. The other calls the Fireworks cloud API.

Start an OpenClaw session:

```
openclaw tui --session workshop
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">openclaw tui --session workshop</script>Paste Command</button>

---

### 1a - Ask the cloud brain

```
/agent cloud-brain
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/agent cloud-brain</script>Paste Command</button>

> Watch the monitor in your second terminal as you run this.

```
Write a Python script that takes a list of employees with start dates and equity grants and calculates who is past their 1-year cliff and how much has vested.
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">Write a Python script that takes a list of employees with start dates and equity grants and calculates who is past their 1-year cliff and how much has vested.</script>Paste Prompt</button>

**Monitor shows:** `provider=fireworks  url=https://api.fireworks.ai` - every token costs money.

---

### 1b - Ask the local brain the same task

```
/agent local-brain
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/agent local-brain</script>Paste Command</button>

> Watch the monitor in your second terminal as you run this.

```
Write a Python script that takes a list of employees with start dates and equity grants and calculates who is past their 1-year cliff and how much has vested.
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">Write a Python script that takes a list of employees with start dates and equity grants and calculates who is past their 1-year cliff and how much has vested.</script>Paste Prompt</button>

**Monitor shows:** `provider=lemonade  url=http://localhost:13305` - same output, AMD GPU, zero API cost.

> **The problem:** You had to decide which agent to use before sending the request. In a real deployment with dozens of request types, that doesn't scale. Act 2 fixes this.

---

## Act 2 - Agentic Routing

**What this shows:** A single agent that reads every request, classifies it as LOCAL or CLOUD on its first line, and automatically delegates to the right model - no manual switching required.

**How it works:** The smart-router agent has a `SOUL.md` file in its workspace. The gateway injects this as a system prompt on every turn. The local Qwen model reads the routing rules and produces `Classification: LOCAL` or `Classification: CLOUD` as its first line.

**The routing policy is a plain markdown file. No ML classifier. No retraining. Edit the file, change the policy.**

```
/agent smart-router
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/agent smart-router</script>Paste Command</button>

---

### LOCAL example

```
What does a 4-year vesting schedule with a 1-year cliff mean?
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">What does a 4-year vesting schedule with a 1-year cliff mean?</script>Paste Prompt</button>

**Expected first line:** `Classification: LOCAL -- factual definition, single deterministic answer`

**Monitor:** one line - `provider=lemonade`. No reasoning required, stays on AMD hardware.

---

### CLOUD example

```
Our Series A cap table has a 1x non-participating liquidation preference. Walk me through how the payout waterfall works if we exit at $60M versus $200M.
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">Our Series A cap table has a 1x non-participating liquidation preference. Walk me through how the payout waterfall works if we exit at $60M versus $200M.</script>Paste Prompt</button>

**Expected first line:** `Classification: CLOUD -- multi-step financial reasoning. Delegating to kimi-k2p6.`

**Monitor:** two lines - `provider=lemonade` (Qwen classifies), then `provider=fireworks` (Kimi does the reasoning).

> Multi-step reasoning is explicitly listed in SOUL.md as a CLOUD trigger

---

**What we just saw:** Rules-based routing works - but it only handles binary decisions. Real workloads are more nuanced: a request containing a name and salary should go local for privacy reasons. A financial model too complex for the local model should escalate automatically. A simple HR policy lookup shouldn't burn cloud tokens.

That's what the vLLM Semantic Router adds: **per-skill routing policies, PII detection, and a confidence loop** - each tuned to the task, not a single binary rule.

---

## Meet the Startup

You're now the head of operations at an AI startup. You have employees to onboard, benefits questions to answer, a cap table to manage, and compliance obligations to meet. The agents below handle each domain - and the vLLM Semantic Router decides, on every request, whether the work stays on your AMD hardware or gets handed to the cloud.

Keep the vLLM SR and Lemonade Server dashboards open in your browser to watch those decisions happen in real time.

## Keep the vLLM SR and Lemonade Server dashboards open in your browser.

1. vLLM Semantic Router at http://localhost:8700
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_11_23_20_181.7whkmda2ujlxzqt1yv6osovj7a0h.png "Click to enlarge")
2. Lemonade Server at http://localhost:13305
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_11_23_21_141.ii466aisy27r56ce01wm6irv6n2c.png "Click to enlarge")

**Ensure you have the logs enabled**

## Enter the OpenClaw session

Start a fresh OpenClaw session from your terminal:

```
openclaw tui --session workshop2
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">openclaw tui --session workshop1</script>OpenClaw tui --session workshop1</button>

---

## 1. HR Admin Agent

**Handles:** Employee records - onboarding, salary/equity updates, role changes, and terminations  
**Routing:** Local (PII-sensitive)  
**Data Source:** `employees.csv`  

#### Agent Goal

Update the employee database located at:

`${HOME}/Downloads/projects/router-configs/data/employees.csv`


#### Try it with the Cloud Model First

**1.** In OpenClaw's terminal, open the model picker:

```
/model
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/model</script>Paste /model</button>

**2.** Select **Kimi K2.6 (Fireworks)** and run:

```
/skill hr-admin Onboard Jordan Lee, ML Platform Engineer, starts August 1, salary $162K, equity 0.6%, email jordan.lee@startup.ai
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill hr-admin Onboard Jordan Lee, ML Platform Engineer, starts August 1, salary $162K, equity 0.6%, email jordan.lee@startup.ai</script>Paste Prompt</button>

**Expected Output:** 
Jordan Lee is added to:

`${HOME}/Downloads/projects/router-configs/data/employees.csv`

**Verdict:** The request contained personally identifiable information (PII), which was sent to a cloud model.

#### Now Try the Semantic Router

**1.** Open the model picker again:

```
/model
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/model</script>Paste /model</button>

**2.** Select **MoM (Custom Provider)** and run:

```
/skill hr-admin Onboard Maya Chen, Senior AI Engineer, starts July 1, salary $175K, equity 0.8%, email maya.chen@startup.ai
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill hr-admin Onboard Maya Chen, Senior AI Engineer, starts July 1, salary $175K, equity 0.8%, email maya.chen@startup.ai</script>Paste Prompt</button>

**Expected Router Flow:** 
PII detected (name, salary, email)

- Routes to **Local Qwen3.5 9B**

- Same result with **zero data egress**

**You can see the local model being loaded, with Lemonade Server displaying logs that include metrics such as TTFT and TPS.**
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_11_23_25_061.1h37w2eqzoxjefothx8oode4kdj6.png "Click to enlarge")

**Expected Output:** 

Maya Chen is added to:

`${HOME}/Downloads/projects/router-configs/data/employees.csv`


#### Additional Example:

```
/skill hr-admin Equity refresh for Kevin Patel - grant an additional 0.3%
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill hr-admin Equity refresh for Kevin Patel - grant an additional 0.3%</script>Paste Prompt</button>

---

## 2. Benefits Agent

**Handles:** Employee self-service questions about benefits, HR policies, and handbook content  
**Data Source:** `benefits_handbook.md`

#### Agent Goal

Perform RAG over:

`${HOME}/Downloads/projects/router-configs/data/benefits_handbook.md`

and answer employee questions.

#### Try it with the Cloud Model First

**1.** In OpenClaw's terminal, open the model picker:

```
/model
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/model</script>Paste /model</button>

**2.** Select **Kimi K2.6 (Fireworks)** and run:

```
/skill benefits When does my 401(k) vesting cliff kick in?
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill benefits When does my 401(k) vesting cliff kick in?</script>Paste Prompt</button>

**Expected Output:** 
The agent retrieves and summarizes the handbook's 401(k) vesting policy.

**Verdict:** A cloud model was used for a simple RAG lookup, increasing inference cost.

#### Now Try the Semantic Router

**1.** Open the model picker again:

```
/model
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/model</script>Paste /model</button>

**2.** Select **MoM (Custom Provider)** and run:

```
/skill benefits What's our parental leave policy compared to industry standard?
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill benefits What's our parental leave policy compared to industry standard?</script>Paste Prompt</button>

**Expected Router Flow:**

HR policy query

- Simple RAG request

- Routes to **Local Qwen3.5 9B**

**Expected Output:** A summary of the company's parental leave policy, including a comparison with common industry practices.

#### Additional Example

```
/skill benefits When do my ISOs expire if I leave the company?
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill benefits When do my ISOs expire if I leave the company?</script>Paste Prompt</button>

---

## 3. Finance Agent

**Handles:** Burn rate, equity modeling, retention analysis, budgeting, and runway forecasting
**Data Sources:** `financials.csv`, `cap_table.csv`, `employees.csv`, `retention_history.csv`

#### Agent Goal

Perform data analysis over the CSV files located in:

`${HOME}/Downloads/projects/router-configs/data/`

and answer financial questions.

> From here the router always handles the request - we're exploring *which* routing decision it makes and why.

#### Ensure OpenClaw session is pointing to MoM (Custom Provider). If needed, switch models using `/model`

```
/skill finance Calculate equity dilution in a B-round at $40M raise on $160M pre-money. Include waterfall scenarios for 1x, 1.5x, 2x liquidation preferences. 
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill finance Calculate equity dilution in a B-round at $40M raise on $160M pre-money. Include waterfall scenarios for 1x, 1.5x, 2x liquidation preferences. 
</script>Paste Prompt</button>

**Expected Router Flow:**

Complex financial modeling

- Multi-step reasoning

- Routes to **Cloud Kimi K2.6**

**Expected Output:** Detailed dilution calculations, waterfall tables, and scenario analysis.

#### Confidence Loop: Local and Cloud Models Working Together
```
/skill finance One of our employees got a competitor offer in Q1 2026 and we took no action - based on what worked best historically, what intervention should we make now, and what does it cost us through year end?   
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill finance One of our employees got a competitor offer in Q1 2026 and we took no action - based on what worked best historically, what intervention should we make now, and what does it cost us through year end? </script>Paste Prompt</button>

**Expected Router Flow:** 

**Confidence Loop**

- Pass 1 → Local Qwen3.5 9B attempts the task
- Confidence below threshold
- Automatically escalates to **Cloud Kimi K2.6**

**Additional Example:**
- /skill finance What's our current burn rate and runway?

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill finance What's our current burn rate and runway?</script>Paste Prompt</button>

---

## 4. **Legal Agent**

**Handles:** Regulatory research, compliance guidance, contract review, and legal Q&A
**Data Sources:** Live web search and uploaded contracts

#### Agent Goal

Perform web search and RAG over uploaded legal documents to answer legal and compliance questions.

#### Ensure OpenClaw session is pointing to MoM (Custom Provider). If needed, switch models using `/model`

#### Example 1
```
/skill legal What GDPR compliance and data protection regulatory requirements apply to an AI vendor under EU privacy law?
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill legal What GDPR compliance and data protection regulatory requirements apply to an AI vendor under EU privacy law?
 
</script>Paste Prompt</button>

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

**Additional Example:**
- /skill legal Can we require offshore contractors to assign IP they develop for us?

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill legal Can we require offshore contractors to assign IP they develop for us?</script>Paste Prompt</button>

---

## Workshop Challenges - We have prizes 🏆!

Complete **both** challenges to win the grand prize.

Complete **at least one** challenge to receive a participation prize.

#### Challenge 1: 
Build an AI-powered analytics application.

Your task is to prompt the **R&D Agent** to:

- Analyze the startup datasets
- Build a stock price prediction model
- Generate an interactive dashboard to visualize the predictions

#### Hint:

Use:
```
/skill rnd
```
Explore the **vLLM Semantic Router configuration** to ensure a sufficiently powerful local model is enabled.


#### Challenge 2

Use the **Audio Operations Agent** to transcribe the MP3 recording located at:
`${HOME}/Downloads/projects/router-configs/data/transcripts`
and extract key decisions and action items.

#### Hint

Use:
```
/skill ops-audio
```
and instruct the agent to transcribe the `.mp3` file in the directory.

---
