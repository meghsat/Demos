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

### How the system works

**OpenClaw** is the agent runtime. It manages sessions, loads workspace files as system prompts, and calls tools on behalf of the model. Every agent in this workshop runs inside OpenClaw.

**Skills** give agents their context. Each skill injects:
- A pointer to the relevant data source (`employees.csv`, `benefits_handbook.md`, cap table CSVs)
- Output expectations (what a correct response looks like)
- Operation guidelines (e.g. soft-delete only, never overwrite existing records)

**The vLLM Semantic Router** sits between OpenClaw and the models. On every request it decides:
- **PII detected?** (names, emails, salaries) → stays on local AMD hardware
- **Simple lookup or RAG?** → local model handles it, no cloud cost
- **Complex reasoning?** → escalates to cloud
- **Local model not confident enough?** → confidence loop kicks in, escalates automatically

System Architecture<a class="story_video" href="https://youtu.be/rFdrjZPtaKY">Click this to view the video</a>
---

# Lab Setup
> **Tip:** Each command below includes a **Paste** button. First, click where you want the command to be pasted in the instance. Then click Paste to insert the command automatically, no typing required. Review the command, then press Enter.

### Google Chrome
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_15_01_21_181.0osuhbxypzi32hfifkyila2hsi29.png "Click to enlarge")

### Terminal Emulator
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_17_04_40_021.sk62591tezew6k8566z10w3wpb7l.png "Click to enlarge")  

---

1. Open Google Chrome
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_15_01_21_181.0osuhbxypzi32hfifkyila2hsi29.png "Click to enlarge")

2. Go to ```https://notebooks.amd.com/codes/fireworks```
<button class="dark" onclick="ConsolePaste('https://notebooks.amd.com/codes/fireworks')" btn_type="paste" type="button">Paste URL<Fireworks Api-Key></button>  

and enter password ```AAIOpenclaw2026``` to get the Fireworks API Key. **Keep the API key handy.** 

<button class="dark" onclick="ConsolePaste('AAIOpenclaw2026')" btn_type="paste" type="button">Paste Password<Fireworks Api-Key></button>  

3. Launch the Terminal
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_17_04_40_021.sk62591tezew6k8566z10w3wpb7l.png "Click to enlarge")  

4. Run `./hybrid-multi-agent-openclaw/start-vllm-sr.sh <Fireworks Api-Key>`  
<button class="dark" onclick="ConsolePaste('./hybrid-multi-agent-openclaw/start-vllm-sr.sh <Paste Fireworks Api-Key>')" btn_type="paste" type="button">Paste Command</button>

5. The previous command should have opened the vLLM SR dashboard. If it didn't, open Google Chrome on the instance and navigate to ```http://localhost:8700```. Click **Enter Dashboard** and log in to the Semantic Router dashboard.
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_17_04_43_501.ihax2ppml47naq76oim1g1cjh6zl.png "Click to enlarge")

Enter the below login credentials: 
```aai26@amd.com``` and ```aai26```

<button class="dark" onclick="ConsolePaste('aai26@amd.com')" btn_type="paste" type="button">Email</button>  

<button class="dark" onclick="ConsolePaste('aai26')" btn_type="paste" type="button">Password</button>

6. Run `./hybrid-multi-agent-openclaw/start-openclaw.sh <Fireworks Api-Key>`
<button class="dark" onclick="ConsolePaste('./hybrid-multi-agent-openclaw/start-openclaw.sh <Paste Fireworks Api-Key>')" btn_type="paste" type="button">Paste Command</button>


7. In a terminal run:

```
openclaw tui --session workshop
```
<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">openclaw tui --session workshop</script>Paste Command</button> 

![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_19_18_47_571.ore6la560tc5e6pp9bm9cqhsb6bg.png "Click to enlarge")

Inside the OpenClaw TUI run:
```
/model
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/model</script>Paste /model</button>

Select **Kimi K2.6 (Fireworks)**
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_16_00_37_081.3a1gd84hfm1bqpx523frpr8natji.png "Click to enlarge")

Introduce yourself:
```
Hey! I'm <YOUR-NAME>
```

> **Tip:** Each command below includes a **Paste** button. First, click where you want the command to be pasted in the instance. Then click Paste to insert the command automatically, no typing required. Review the command, then press Enter.

---
#### Lemonade Server Dashboard

Open Google Chrome and go to ```http://localhost:13305```  
 
<button class="dark" onclick="ConsolePaste('http://localhost:13305')" btn_type="paste" type="button">Paste URL<Fireworks Api-Key></button> 

ensure the logs are enabled **View > Logs**
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_11_23_21_141.ii466aisy27r56ce01wm6irv6n2c.png "Click to enlarge")

---
## Act 1: Local vs Cloud Brain

Every OpenClaw agent has a configuration that defines what tools it is allowed to use.

For the Cloud Brain, we'll remove access to the filesystem and runtime tools. This means the agent can still answer questions, but it **won't be able to read local files or execute commands.**

In a **fresh terminal**, run:

![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_19_20_22_161.2lxc8jatry4zzu3b38nnlx3a8qsw.png "Click to enlarge")
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

Now let's see that policy in action. You can either return to the previously started OpenClaw session or restart it:

```
openclaw tui --session workshop
```
<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">openclaw tui --session workshop</script>Paste Command</button> 


### 1a - Cloud Brain

```
/agent cloud-brain
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/agent cloud-brain</script>Paste Command</button>


```
Read the contents of ${HOME}/Downloads/projects/router-configs/data/financials.csv
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">Read the contents of ${HOME}/Downloads/projects/router-configs/data/financials.csv</script>Paste Prompt</button> 

The agent **refuses** - not because it can't, but because its policy says it shouldn't. 

## Let's track the Tokenomics with a live routing monitor

In a **fresh terminal** run:

```
./hybrid-multi-agent-openclaw/tokenomics.sh
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">./hybrid-multi-agent-openclaw/tokenomics.sh</script>Paste Command</button>

**Tokenomics monitor shows:** ROUTING=CLOUD

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


### 1b - Local Brain - Same task. Same capability. Different boundary

Return to the previously started OpenClaw session, or restart it if needed.


```
openclaw tui --session workshop
```
<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">openclaw tui --session workshop</script>Paste Command</button> 

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

> **The problem:**

You still had to decide which agent to use before sending the request. In a real deployment with dozens of request types, that doesn't scale.

What if the agent could decide for itself? **Act 2 fixes this.**

--- 

## Act 2 - The Smart Router: One Agent, Multiple Brains

**Scenario:** A single agent that reads every request, classifies it as LOCAL or CLOUD, and delegates to the right model - no manual switching required. 

**Any guesses how we get this to work?** 

<details>
Just like the Cloud/Local Brains, the Smart Router has its own **SOUL.md**. But this time, the policy has a different purpose: it doesn't control what the agent can access - it teaches the agent how to decide where each request should run.
</details>

In a **fresh terminal** outside your OpenClaw TUI:

```
cat ~/.openclaw/workspace-smart-router/SOUL.md
```
<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">cat ~/.openclaw/workspace-smart-router/SOUL.md</script>Paste Command</button>

Back in your OpenClaw TUI switch to the Smart Router:
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

That's what the **vLLM Semantic Router** adds: **per-skill routing policies, PII detection, and a confidence loop** - each tuned to the task, not a single binary rule.

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

1. vLLM Semantic Router at ```http://localhost:8700```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">http://localhost:8700</script>Paste URL</button> 

![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_11_23_20_181.7whkmda2ujlxzqt1yv6osovj7a0h.png "Click to enlarge")
2. Lemonade Server at ```http://localhost:13305``` - Ensure you have the logs enabled **View > Logs**

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">http://localhost:13305</script>Paste URL</button> 

![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_11_23_21_141.ii466aisy27r56ce01wm6irv6n2c.png "Click to enlarge")


### Enter the OpenClaw session

Start a **fresh OpenClaw session** in a new terminal:

```
openclaw tui --session workshop2
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">openclaw tui --session workshop2</script>OpenClaw tui --session workshop2</button>

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

**Verdict:** The request contained **personally identifiable information (PII)**, which was sent to a cloud model.

#### Now Try the Semantic Router

**1.** Open the model picker again:

```
/model
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/model</script>Paste /model</button>

<span style="color:red">**NOTE**:</span> The dropdown might be misplaced in the middle of the TUI but should like this
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_17_05_22_511.pvw9899i8crm4hzcm3g93hb3qe7h.png "Click to enlarge")
**2.** Select **MoM (Custom Provider)** and run: 

```
/skill hr-admin Onboard Maya Chen, Senior AI Engineer, starts July 1, salary $175K, equity 0.8%, email maya.chen@startup.ai
```

<button class="dark" onclick="ConsolePaste('/skill hr-admin Onboard Maya Chen, Senior AI Engineer, starts July 1, salary $175K, equity 0.8%, email maya.chen@startup.ai')" type="button">Paste Prompt</button>

**Expected Router Flow:** 
PII detected (name, salary, email)

- Routes to **Local Qwen3.5 9B**

- Same result with **zero data egress**

**You can see the local model being loaded, with Lemonade Server displaying logs that include metrics such as TTFT and TPS.**
![Click to enlarge](https://techaccelerator.s3.us-west-2.amazonaws.com/portal/AMD/2026_07_11_23_25_061.1h37w2eqzoxjefothx8oode4kdj6.png "Click to enlarge")

**Expected Output:** 

Maya Chen is added to:

`${HOME}/Downloads/projects/router-configs/data/employees.csv`

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

**Verdict:** A cloud model was used for a simple RAG lookup, **increasing inference cost.**

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

---

## 3. Finance Agent

**Handles:** Burn rate, equity modeling, retention analysis, budgeting, and runway forecasting  
**Data Sources:** `financials.csv`, `cap_table.csv`, `employees.csv`, `retention_history.csv`

#### Agent Goal

Perform data analysis over the CSV files located in:

`${HOME}/Downloads/projects/router-configs/data/`

and answer financial questions.

**Ensure OpenClaw session is pointing to MoM (Custom Provider).** If needed, switch models using `/model`

## Confidence Loop: Local and Cloud Models Working Together
```
/skill finance One of our employees got a competitor offer in Q1 2026 and we took no action - based on what worked best historically, what intervention should we make now, and what does it cost us through year end?   
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill finance One of our employees got a competitor offer in Q1 2026 and we took no action - based on what worked best historically, what intervention should we make now, and what does it cost us through year end?</script>Paste Prompt</button>

**Expected Router Flow:** 

**Confidence Loop**

- Pass 1 → Local Qwen3.5 9B attempts the task
- Confidence below threshold
- Automatically escalates to **Cloud Kimi K2.6**

---
## 4. **Legal Agent**

**Handles:** Regulatory research, compliance guidance, contract review, and legal Q&A  
**Data Sources:** Live web search and uploaded contracts

#### Agent Goal

Perform web search and RAG over uploaded legal documents to answer legal and compliance questions.

**Ensure OpenClaw session is pointing to MoM (Custom Provider). If needed, switch models using `/model`**

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

---

## Workshop Challenges - We have prizes 🏆!

### Build a Stock Prediction Dashboard

Use any approach from this workshop to prompt the **R&D Agent** to analyze the startup datasets, build a stock price prediction model, and generate an interactive dashboard.

**Your dashboard must include all two of these to qualify:**

- A **date range slider** to filter between historical and future predicted data
- At least **two suggested features** the model identified as predictive (e.g. burn rate trend, headcount growth)

**Track the tokenomics monitor** in a second terminal before you begin - your cost will be checked at judging time:

The monitor tracks every turn: LOCAL turns cost fractions of a cent, CLOUD turns cost real money. The winning team builds a qualifying dashboard with the lowest **Total** shown at the bottom of the tokenomics output.

```
/skill rnd
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill rnd</script>Paste Command</button>

---
## Take Home Challenge
### Audio Transcription and Action Item Extraction

Use the **Audio Operations Agent** to transcribe the MP3 recording located at:

`${HOME}/Downloads/projects/router-configs/data/transcripts`

and extract key decisions and action items from the meeting.

```
/skill ops-audio
```

<button class="dark" onclick="ConsolePaste(this.children[0].innerText)" type="button"><script type="template">/skill ops-audio</script>Paste Command</button>

Instruct the agent to find and transcribe the `.mp3` file in that directory, then produce a structured summary of decisions made and follow-up actions assigned.


---
