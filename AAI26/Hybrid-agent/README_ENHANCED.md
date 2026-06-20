# Managing a Startup using Openclaw powered by a hybrid vLLM Semantic Router

This workshop demonstrates a **hybrid local/cloud agent system** powered by vLLM Semantic Router and Openclaw. Learn how to build cost-efficient, privacy-aware AI agents that intelligently route queries between local and cloud models.

---

## Workshop Levels

### **Level 1: Basic Routing**
- Keyword-based routing
- PII detection → local
- Simple vs complex queries
- 6 agent skills demo

### **Level 2: Advanced Routing**
- MMBERT complexity scoring
- Confidence loop escalation
- Domain classification
- Context-based routing
- Feedback detection

### **Level 3: Production Patterns**
- Multi-pass PII redaction
- Cost optimization analysis
- Observability & debugging
- Router config tuning

---

## System Architecture

-----> Put the Claude design graphic here
```
User Query
    ↓
Openclaw Agent (reads CSVs, writes code, generates responses)
    ↓
vLLM Semantic Router (analyzes & routes)
    ├─ MMBERT Complexity Scoring
    ├─ PII Detection (names, emails, SSN)
    ├─ Domain Classification (law, CS, finance)
    ├─ Context Size Analysis (8K+ tokens)
    ├─ Confidence Loop (try local → escalate)
    └─ Feedback Detection (user corrections)
    ↓
Routing Decision
    ├─ Local: Qwen 9B ($0.00/query, PII-safe, fast)
    └─ Cloud: Kimi K2 ($0.30/query, powerful, complex)
    └─ Local: Whisper ($0.00/query, Speech-to-Text)
    └─ Local: Qwen 35B ($0.00/query, PII-safe, powerful, complex)
```

---

## Workshop Agents (6 Skills)

### 1. **HR Admin Agent**
**Routing:** Local (PII-sensitive)  
**Data:** `employees.csv`

**Basic Example:**
```
/skill hr-admin onboard Maya Chen, Senior AI Engineer, starts July 1, 
salary $175K, equity 0.8%, email maya.chen@startup.ai
```
**Router:** PII detected (name, salary, email) → **Local 9B**

---

### 2. **Benefits Agent**
**Data:** `benefits_handbook.md`

```
/skill benefits What's our parental leave policy compared to industry standard?
```
**Router:**
- Complexity: Medium
- Decision: hr_policy_keywords → simple query → **Local 9B**

---

### 2. **Finance Agent**
**Data:** `financials.csv`, `cap_table.csv`, `employees.csv`, `retention_history.csv`

**Basic Example (Simple):**
```
/skill finance what's our current burn rate and runway?
```
**Router:** Simple keywords ("burn rate") → **Local 9B**

**Basic Example (Complex):**
```
/skill finance Model equity dilution in Series B at $40M raise on $160M pre-money. 
Include waterfall scenarios for 1x, 1.5x, 2x liquidation preferences.
```
**Router:** Finance modeling keywords + multi-step → **Cloud Kimi K2**

**Advanced Example (Confidence Loop):**
```
/skill finance One of our employees got a competitor offer in Q1 2026 and we took no action — based on what worked best historically, what intervention should we make now, and what does it cost us through year end?   
```
**Router:**
- Decision: **Confidence loop**
  - Pass 1: Local 9B tries → confidence < Threshold
  - Pass 2: Escalates to Cloud

**Advanced Example (PII Redaction - Multi-Pass):**
```
/skill finance For Sarah Kim's retention, compare Option A (20% raise) vs 
Option B (0.5% equity refresh). Model 4-year NPV.
```
**Router:** PII detected (name) → **Local 9B** (priority 1000)

**Agent Multi-Pass Workflow:**
1. **Local**: Detect "Sarah Kim" → redact to `[EMPLOYEE_A]`
2. **Cloud**: Complex NPV modeling with anonymized data
3. **Local**: Restore name, add privacy disclaimer

---

### 3. **Legal Agent**
**Routing:** Cloud (regulatory research)  
**Data:** Web search, uploaded contracts

**Basic Example:**
```
/skill legal What are latest GDPR requirements for AI products processing EU user data?
```
**Router:** Legal keywords ("GDPR") → **Cloud Kimi K2**

**Advanced Example (Domain Classification):**
```
/skill legal Can we enforce non-compete clauses for engineers in California?
```
**Router:**
- Keywords: No explicit legal terms
- Domain: **Law** (93% confidence via MMLU classifier)
- Decision: `workshop_legal_cloud` → **Cloud Kimi K2**
- Why: Semantic understanding caught legal topic despite no buzzwords

---

### 4. **R&D Agent**
**Routing:** Cloud (system design, greenfield architecture)  
**Data:** None (novel design, no existing codebase)

**Basic Example:**
```
/skill rnd Design a fraud detection ML pipeline for fintech transactions. 
Propose architecture, models, and infrastructure.
```
**Router:** R&D keywords ("design", "ML pipeline", "fraud detection") → **Cloud Kimi K2**

**Advanced Example (Domain + Complexity):**
```
/skill rnd How would you build a recommendation system for 100M users with <100ms latency?
```
**Router:**
- Keywords: Partial ("recommendation system")
- Domain: **Computer Science** (91% confidence)
- Complexity: High (0.74 score)
- Decision: `workshop_rnd_cloud` → **Cloud Kimi K2**
- Why: Multi-signal confirmation (domain + complexity + partial keywords)

---

### 5. **Operations - Audio Agent**
**Routing:** Local (meeting transcription, PII-sensitive)  
**Modality:** Audio (MP3, WAV, M4A)

**Basic Example:**
```
/skill ops-audio Transcribe this exec meeting and extract key decisions, 
action items, and budget concerns.
[Attach: exec_meeting.mp3 - 47 minutes]
```
**Router:** Audio file detected → **Local 9B** (modality priority 900)

**Advanced Example (Context Escalation):**
```
/skill ops-audio Transcribe this 2-hour board meeting, then:
1. Summarize strategic decisions
2. Extract all financial commitments
3. Identify compliance risks
4. Create action items with owners
[Attach: board_meeting_2hr.mp3]
→ Whisper transcription: 18,243 tokens
```
**Router:**
- Step 1: Audio → Local Whisper (PII-safe transcription)
- Step 2: Detect context size: **18,243 tokens**
- Step 3: Match `large_context` signal (8K+ threshold)
- Decision: `workshop_large_context_cloud` → **Cloud Kimi K2**
- Why: Long transcript needs 262K context window for full analysis

---

### 6. **Operations - Vision Agent**
**Routing:** Local (dashboard analysis, business metrics)  
**Modality:** Vision (PNG, JPG)

**Basic Example:**
```
/skill ops-vision Analyze this metrics dashboard and identify concerning trends
[Attach: dashboard.png]
```
**Router:** Vision file detected → **Local 9B** (modality priority 900)

**Advanced Example (Long Query):**
```
/skill ops-vision Analyze this Q4 dashboard. For each metric:
1. Calculate quarter-over-quarter % change
2. Flag if >2σ from historical average
3. Identify correlated metrics (e.g., churn ↑ when engagement ↓)
4. Recommend 3 specific actions per critical issue
5. Estimate impact if we implement top recommendation
[Attach: q4_dashboard.png]
```
**Router:**
- Modality: Vision file → Local priority
- Query length: 67 words (below 400 threshold)
- Complexity: Medium (0.48 score)
- Decision: **Local 9B** (modality wins priority)
- Note: If query was >400 words, `long_query` signal (priority 650) would override modality

---

## Advanced Routing Features

### 1. MMBERT Complexity Scoring
**What:** ML model scores reasoning complexity (0-1 scale)  
**When:** Semantic difficulty detection beyond keywords

**Example:**
```
Query: "Compare retention strategies across compensation, equity, 
        and growth opportunities. Model 4-year NPV for each."
```
- Complexity score: **0.68** (high)
- Triggers: `needs_reasoning:high`
- Routing: Cloud (priority 600)

vs.

```
Query: "What's our burn rate?"
```
- Complexity score: **0.09** (low)
- Triggers: `needs_reasoning:low`
- Routing: Local (priority 500)

---

### 2. Confidence Loop (Cost Optimization)
**What:** Try local → self-assess → escalate to cloud if uncertain  
**When:** Medium complexity queries (score 0.28-0.6)

**Example Flow:**
```
Query: /skill finance Estimate runway if we reduce burn by 15%

Pass 1 (Local 9B):
  Response: "With 15% reduction, runway extends from 18 to 21 months"
  Confidence: 0.74  (below 0.8 threshold)
  
Pass 2 (Cloud Kimi K2):
  Response: "Current burn $287K/mo, reduced to $244K/mo = 21.3 months runway
            (based on financials.csv: $5.2M cash, $287K avg monthly burn)"
  Confidence: 0.92 
  
Final: Use cloud response
Cost: $0.31 (local attempt + cloud escalation)
```
---

### 3. Domain Classification (MMLU)
**What:** 14-category MMLU classifier for semantic categorization  
**When:** Queries lack explicit keywords but have domain semantics

**Example:**
```
Query: /skill legal Can we require engineers to sign non-competes during hiring?
```
- Keywords: No "GDPR", "compliance", "regulation"
- Domain: **Law** (95% confidence)
- Routing: Cloud (priority 800)

**Why This Matters:** Catches "stealth" legal/technical queries that slip through keyword filters.

---

### 4. Context-Based Routing
**What:** Routes 8K+ token queries to cloud for capacity  
**When:** Long documents, multi-file RAG, large transcripts

**Threshold:**
- Local 9B: 256K context window → comfortable up to 8K tokens
- Cloud Kimi K2: 262K context window → handles 8K-100K tokens

**Example:**
```
/skill legal Review this 45-page vendor contract for GDPR compliance
[Attach: vendor_agreement.pdf]
→ PDF OCR: 12,847 tokens
```
- Context signal: `large_context` (>8K)
- Routing: Cloud (priority 850)

---

### 5. Feedback Detection
**What:** Detects user dissatisfaction and re-routes  
**When:** Follow-up corrections, "try again" requests

**Example:**
```
Turn 1:
User: /skill finance estimate Series B dilution
Router: Medium complexity → Confidence loop → Local 9B (conf 0.76)
Response: "Typically 15-25% dilution in Series B"

Turn 2:
User: That's too generic. I need actual numbers for our cap table.
Router: Feedback → "dissatisfied" (0.89 confidence)
Action: Override to cloud, add correction context
Response: "Based on cap_table.csv: 20% dilution (40M/200M), your 8% → 6.4%"
```

---

## Workshop Challenges

### Challenge 1: Multi-Signal Priority
**Query:**
```
/skill finance For Sarah Kim (sarah@company.com, $180K salary), model equity 
dilution in Series B with 1x vs 2x liquidation preferences and waterfall analysis.
```

**Signals Detected:**
1. PII: name, email, salary (priority 1000)
2. Finance keywords: "equity dilution", "waterfall" (priority 600)
3. Complexity: high (0.71 score) (priority 600)
4. Multi-step: "1x vs 2x" (priority 600)

**Question:** Which signal wins?

<details>
<summary>Answer</summary>

**Winner:** PII (priority 1000) → Local 9B

**Why:** Security always overrides complexity. PII must be handled locally.

**Correct Flow:**
1. Local: Detect & redact PII
2. Cloud: Complex modeling with anonymized data
3. Local: Restore PII, add disclaimer

</details>

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

<details>
<summary>Answer</summary>

**All-Local:**
- Cost: 100 × $0.01 = **$1.00/day**
- Accuracy: 70% (30 queries wrong)

**All-Cloud:**
- Cost: 100 × $0.30 = **$30.00/day**
- Accuracy: 99%

**Confidence Loop:**
- Simple (70): Local only = $0.70
- Medium (20): 50% escalate = $3.10 (10 local $0.10 + 10 cloud $3.00)
- Complex (10): Always escalate = $3.00
- **Total: $6.80/day** (77% savings vs all-cloud)
- Accuracy: 95%

</details>

---

### Challenge 3: Domain Blind Spot
**Task:** Find a finance query that:
- Contains NO finance keywords
- DOES trigger domain classifier
- Tests semantic understanding

<details>
<summary>Example Answer</summary>

```
/skill finance How much runway do we lose if headcount grows 30% next quarter?
```

- Keywords: ❌ No "burn rate", "runway", "dilution"
- Domain: ✅ **Finance** (econometrics category)
- Complexity: Medium
- Routing: Confidence loop (medium) or Cloud (domain)

</details>

---

## Router Decision Observability

**TUI Output Example:**
```
🧭 router → Kimi-K2p6 | decision=workshop_confidence_loop (conf 0.91) | 
complexity=needs_reasoning:medium | domain=finance | escalated=true | iters=2 | 
cost=$0.31
```

**Breakdown:**
- `decision=workshop_confidence_loop` - Used confidence algorithm
- `conf 0.91` - Final confidence score
- `complexity=needs_reasoning:medium` - MMBERT scored 0.42
- `domain=finance` - MMLU classified as finance domain
- `escalated=true` - Tried local first, then escalated
- `iters=2` - Ran 2 models (local + cloud)
- `cost=$0.31` - Token cost for this query

---

## Cost Analysis (Real Numbers)

**Baseline Assumptions:**
- Local 9B: $0.10/1M input, $0.20/1M output → ~$0.01/query
- Cloud Kimi K2: $3.00/1M input, $9.00/1M output → ~$0.30/query
- Average query: 500 input tokens, 2000 output tokens

**Monthly Cost (1000 queries/day):**
| Agent | Queries/Day | Local % | Cloud % | Cost/Day | Cost/Month |
|-------|-------------|---------|---------|----------|------------|
| HR | 200 | 95% (PII) | 5% | $2.20 | $66 |
| Finance | 300 | 40% (simple) | 60% (complex) | $57.00 | $1,710 |
| Legal | 100 | 0% | 100% | $30.00 | $900 |
| R&D | 150 | 0% | 100% | $45.00 | $1,350 |
| Ops-Audio | 150 | 100% (local Whisper) | 0% | $1.50 | $45 |
| Ops-Vision | 100 | 100% (local OCR) | 0% | $1.00 | $30 |
| **Total** | **1000** | **41%** | **59%** | **$136.70** | **$4,101** |

**vs. All-Cloud:** $300/day = $9,000/month → **54% savings**

**With Confidence Loop (Finance):**
- Finance queries drop to $21/day (63% savings)
- **New total: $100.70/day = $3,021/month (66% savings)**

---

## Setup Instructions

1. **Deploy Router:**
   ```bash
   cd semantic-router
   docker-compose up -d
   ```

2. **Configure Openclaw:**
   ```bash
   # Point to router endpoint
   export ROUTER_URL=http://localhost:8899/v1
   
   # Add Fireworks API key to config
   vim config_workshop_enhanced.yaml
   # Line 34: api_key: fw_XXXXX
   ```

3. **Load Workshop Skills:**
   ```bash
   cd openclaw
   cp -r workshop/agents ~/.openclaw/skills/
   ```

4. **Run Workshop:**
   ```bash
   # Basic routing demo
   openclaw --workshop basic
   
   # Advanced routing features
   openclaw --workshop advanced
   ```

---

## Workshop Flow

### Part 1: Basic Routing (30 min)
1. **HR Demo** - PII detection (employee onboarding)
2. **Finance Demo** - Simple vs complex (burn rate vs dilution)
3. **Legal Demo** - Cloud research (GDPR)
4. **Show TUI Output** - Router decision metadata

### Part 2: Advanced Features (45 min)
5. **Complexity Scoring** - Finance multi-scenario
6. **Confidence Loop** - Cost optimization demo
7. **Domain Classification** - Legal query without keywords
8. **Context Routing** - Long meeting transcript
9. **Multi-Signal Priority** - PII override challenge

### Part 3: Production Patterns (30 min)
10. **Cost Analysis** - ROI calculations
11. **Multi-Pass PII** - Finance redaction workflow
12. **Observability** - Reading router decisions
13. **Config Tuning** - Adjusting thresholds

---

## Files

| File | Purpose |
|------|---------|
| `agents/*.md` | 6 agent skill definitions |
| `data/*.csv` | Dummy employee/financial data |
| `config_workshop_enhanced.yaml` | Router config with advanced features |
| `ADVANCED_ROUTING.md` | Deep-dive on ML features |

---

## Key Takeaways

1. **Hybrid routing saves 54-66% costs** vs all-cloud
2. **PII always wins priority** (security > cost > quality)
3. **Confidence loop optimizes medium complexity** (95% accuracy at 5x savings)
4. **Domain classification catches semantic queries** beyond keywords
5. **Multi-pass workflows** (local PII redaction → cloud analysis → local restore)

---

## Next Steps

- Try the challenges in `ADVANCED_ROUTING.md`
- Tune router config thresholds for your use case
- Add custom agents (sales, support, DevOps)
- Deploy to production with observability (Jaeger, Prometheus)

**Questions?** Check `ADVANCED_ROUTING.md` or ask during Q&A!