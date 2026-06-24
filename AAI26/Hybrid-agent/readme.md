# Managing a Startup using Openclaw powered by a hybrid vLLM Semantic Router

This workshop demonstrates a **hybrid local/cloud agent system** powered by vLLM Semantic Router and Openclaw. Learn how to build cost-efficient, privacy-aware AI agents that intelligently route queries between local and cloud models.

1. **Semantic Router** handles:
   - PII detection (SSN, names, emails)
   - Input classification (simple vs complex)
   - Initial routing decision

2. **Openclaw Agent** handles:
   - Reading/writing CSV files
   - Calculations and data analysis
   - Generating responses
   - Writing code when needed

3. **Skills** provide:
   - Data source pointers ("read employees.csv")
   - Output expectations ("include privacy disclaimer")
   - Operation guidelines ("soft delete, don't hard delete")

---

## System Architecture

<p align="center">
  <img src="https://github.com/user-attachments/assets/46b4bf51-2b16-4771-bac2-7471cde2aad9"
       width="600"
       alt="Image">
</p>
     
---

## Workshop Agents

### 1. **HR Admin Agent**
**Handles**: Employee records — onboarding, salary/equity updates, role changes, and terminations
**Routing:** Local (PII-sensitive)  
**Data:** `employees.csv`

```
/skill hr-admin onboard Maya Chen, Senior AI Engineer, starts July 1, salary $175K, equity 0.8%, email maya.chen@startup.ai
```
**Router:** 
- PII detected (name, salary, email) → **Local Qwen3.5 9B**

**Additional Examples:**
- /skill hr-admin equity refresh for Kevin Patel — grant an additional 0.3%

---

### 2. **Benefits Agent**
**Handles**: Employee self-service queries on benefits, policies, and HR handbook sections
**Data:** `benefits_handbook.md`

```
/skill benefits What's our parental leave policy compared to industry standard?
```
**Router:**
- hr_policy_keywords → simple query → **Local Qwen3.5 9B**

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
/skill finance One of our employees got a competitor offer in Q1 2026 and we took no action — based on what worked best historically, what intervention should we make now, and what does it cost us through year end?   
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
**Handles:** Audio meeting transcription and analysis — decisions, action items, budget highlights, and strategic themes
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
