# Building a Hybrid Multi-Agent Openclaw System from Client to Cloud

This workshop demonstrates a **hybrid local/cloud agent system** powered by vLLM Semantic Router and Openclaw. Learn how to build cost-efficient, privacy-aware AI agents that intelligently route queries between local and cloud models.

1. **Semantic Router** handles initial routing decision by:
   - PII detection (SSN, names, emails)
   - Input classification (simple vs complex)

2. **Openclaw Agent** handles:
   - Reading/writing CSV files
   - Calculations and data analysis
   - Generating responses
   - Writing code when needed

3. **Skills** provide:
   - Data source pointers ("read employees.csv")
   - Output expectations
   - Operation guidelines ("soft delete, don't hard delete")

---

## System Architecture

https://github.com/user-attachments/assets/46b4bf51-2b16-4771-bac2-7471cde2aad9
     
---

## Prerequisites

### vLLM SR Setup

1. Set the config directory:
```bash
export VLLM_SR_STATE_ROOT_DIR="${VLLM_SR_STATE_ROOT_DIR:-$HOME/Downloads/projects/router-configs}"
```

2. Stop the semantic router:
```bash
vllm-sr stop
```
---
### Fireworks API Key

1. Visit [https://notebooks.amd.com/codes/fireworks](https://notebooks.amd.com/codes/fireworks) - password: `AAIOpenclaw2026` to fetch your Fireworks token

2. Inject the token into the router and openclaw configs:
```bash
export NEW_API_KEY="<new_fireworks_api_key>"

YAML_CONFIG="$VLLM_SR_STATE_ROOT_DIR/config_workshop_enhanced.yaml"
JSON_CONFIG="$HOME/.openclaw/openclaw.json"

NEW_API_KEY="$NEW_API_KEY" \
yq -i '
.providers.models[] |= (
  if .name == "accounts/fireworks/models/kimi-k2p6"
  then .backend_refs[0].api_key = env(NEW_API_KEY)
  else .
  end
)
' "$YAML_CONFIG"

jq --arg api_key "$NEW_API_KEY" \
'.models.providers.fireworks.apiKey = $api_key' \
"$JSON_CONFIG" > "${JSON_CONFIG}.tmp" &&
mv "${JSON_CONFIG}.tmp" "$JSON_CONFIG"
```
3. start the semantic router:
```bash
vllm-sr serve --config $VLLM_SR_STATE_ROOT_DIR/config_workshop_enhanced.yaml --image-pull-policy never
```
---

### OpenClaw Setup

1. Restart the OpenClaw gateway:
```bash
openclaw gateway restart
```

2. Start a new OpenClaw session:
```bash
openclaw tui --session ws1
```

---

## Workshop Agents

### 1. **HR Admin Agent**
**Handles**: Employee records - onboarding, salary/equity updates, role changes, and terminations  
**Routing:** Local (PII-sensitive)  
**Data:** `employees.csv`

**Step 1:** Switch to the cloud model. In OpenClaw's terminal type:
```
/model
```
Select **Kimi K2 (Fireworks)**, then run:
```
/skill hr-admin onboard Jordan Lee, ML Platform Engineer, starts August 1, salary $162K, equity 0.6%, email jordan.lee@startup.ai
```

**Expected Output:** 
- Jordan Lee gets added to ${HOME}/Downloads/projects/router-configs/data/employee.csv

**Step 2:** Switch to the semantic router. In OpenClaw's terminal type:
```
/model
```
Select **MoM (Custom Provider)**, then run:
```
/skill hr-admin onboard Maya Chen, Senior AI Engineer, starts July 1, salary $175K, equity 0.8%, email maya.chen@startup.ai
```

**Expected Router Flow:** 
- PII detected (name, salary, email) → **Local Qwen3.5 9B** - same answer, zero data egress.

**Expected Output:** 
- Maya Chen gets added to ${HOME}/Downloads/projects/router-configs/data/employee.csv

**Additional Examples:**
- /skill hr-admin equity refresh for Kevin Patel - grant an additional 0.3%

---

### 2. **Benefits Agent**
**Handles**: Employee self-service queries on benefits, policies, and HR handbook sections  
**Data:** `benefits_handbook.md`

**Step 1:** Switch to the cloud model. In OpenClaw's terminal type:
```
/model
```
Select **Kimi K2 (Fireworks)**, then run:
```
/skill benefits When does my 401(k) vesting cliff kick in?
```

**Step 2:** Switch to the semantic router. In OpenClaw's terminal type:
```
/model
```
Select **MoM (Custom Provider)**, then run:
```
/skill benefits What's our parental leave policy compared to industry standard?
```

**Expected Router Flow:**
- hr_policy_keywords → simple query → **Local Qwen3.5 9B** - same answer for free of cost

**Expected Output:** 
- Output summarizing the parental leave policy

**Additional Examples:**
- /skill benefits when do my ISOs expire if I leave the company?

---

### 3. **Finance Agent**
**Handles**: Burn rate, equity modeling, retention analysis, and runway analysis  
**Data:** `financials.csv`, `cap_table.csv`, `employees.csv`, `retention_history.csv`


```
/skill finance Calculate equity dilution in a B-round at $40M raise on $160M pre-money. Include waterfall scenarios for 1x, 1.5x, 2x liquidation preferences. 
```
**Router:**
- Finance modeling keywords + multi-step → **Cloud Kimi K2.6**

**Complex Query (Confidence Loop)**
```
/skill finance One of our employees got a competitor offer in Q1 2026 and we took no action - based on what worked best historically, what intervention should we make now, and what does it cost us through year end?   
```
**Router:**
- Decision: **Confidence loop**
  - Pass 1: Local 9B tries → confidence < Threshold
  - Pass 2: Escalates to Cloud

**Additional Examples:**
- /skill finance what's our current burn rate and runway?

---

### 4. **Legal Agent**
**Handles**: Regulatory research, compliance guidance, and contract reviews  
**Data:** Web search, uploaded contracts

**Simple Query (Web Search):**
```
/skill legal What GDPR compliance and data protection regulatory requirements apply to an AI vendor under EU privacy law?
```
**Router:** 
- Legal keywords → **Cloud Kimi K2**

**Advanced Example (Domain Classification):**
```
/skill legal Can we enforce non-compete clauses for employees in California under state contract law?
```
**Router:**
- Decision: `workshop_legal_cloud` → **Cloud Kimi K2**

**Additional Examples:**
- /skill legal can we require offshore contractors to assign IP they develop for us?

---

### 5. **R&D Agent**
**Handles:** Complex engineering pipelines
**Data:** `stock_Laren_ohlc.csv`, `tech_factors_monthly.csv`, `market_factors_monthly.csv`

```
/skill rnd build a stock prediction model from the startup data and visualize it  

```
**Router:** 
- R&D keywords → **Local Qwen3.6 35B**

**Additional Examples:**
- /skill rnd How would you build a recommendation system for 100M users with <100ms latency?

---

### 6. **Operations - Audio Agent**
**Handles:** Audio meeting transcription and analysis - decisions, action items, budget highlights, and strategic themes
**Data:** Audio (MP3, WAV, M4A)

```
/skill ops-audio Transcribe this exec meeting and extract key decisions, action items, and budget concerns.
```

**Router:**
- Audio file detected → **Local Qwen3.5 9B** → **Local Gemma4-E4B**

---

## Workshop Challenges

### Challenge 1: Multi-Signal Priority
**Query:**
```
/skill finance For Sarah Kim (sarah@company.com, $180K salary), model equity 
dilution in Series B with 1x vs 2x liquidation preferences and waterfall analysis.
```

---

### Challenge 2: Confidence Loop ROI
**Scenario:** Finance team asks 100 queries/day
- 70% simple (burn rate, headcount)
- 20% medium (runway estimates, scenario modeling)
- 10% complex (dilution waterfalls, NPV analysis)

**Calculate daily cost:**
1. All-local routing: ?
2. All-cloud routing: ?
3. Confidence loop: ?

---
