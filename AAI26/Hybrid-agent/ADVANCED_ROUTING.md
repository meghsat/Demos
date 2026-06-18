# Advanced Routing Features - Workshop Extension

This document showcases **5 advanced routing techniques** built into the Semantic Router that go beyond simple keyword matching. These demonstrate the router's ML-powered capabilities.

---

## Advanced Features Overview

| Feature | What It Does | When It Triggers | Demo Example |
|---------|-------------|------------------|--------------|
| **MMBERT Complexity Scoring** | ML model scores reasoning complexity | Medium/High complexity queries | Finance multi-scenario analysis |
| **Confidence Loop** | Try local → escalate if uncertain | Medium complexity (score 0.28-0.6) | Ambiguous retention modeling |
| **Domain Classification** | MMLU-style categorization | Legal, CS, Finance domains | Legal query without "GDPR" keyword |
| **Context-Based Routing** | Token count triggers cloud | 8K+ token queries | Long meeting transcript |
| **Feedback Detection** | Detects user dissatisfaction | Follow-up corrections | "That's wrong, try again" |

---

## 1. MMBERT Complexity Scoring 🧠

### What It Does
Uses a **fine-tuned ModernBERT model** to score query complexity on a 0-1 scale based on semantic similarity to "hard" vs "easy" prototype queries.

### How It Works
```yaml
complexity:
  - name: needs_reasoning
    threshold: 0.28  # Score above 0.28 = complex
    hard:
      candidates:
        - "analyze root cause and compare mitigation strategies"
        - "model equity dilution across multiple funding rounds"
    easy:
      candidates:
        - "what is the definition of this term"
        - "what is our burn rate"
```

**Scoring:**
- Compare query embedding to hard/easy prototypes
- Score > 0.6 → High complexity → Cloud
- Score 0.28-0.6 → Medium complexity → Confidence loop
- Score < 0.28 → Low complexity → Local

### Workshop Demo

**Example 1: High Complexity (Cloud)**
```
@finance Compare retention Option A (20% raise + equity refresh) vs 
Option B (promotion + remote flexibility) vs Option C (all of above). 
Model 4-year NPV, Monte Carlo on attrition risk, and break-even timeline.
```

**Router Decision:**
- Complexity score: **0.72** (high)
- Matched: `needs_reasoning:high`
- Decision: `workshop_finance_complex_cloud`
- Model: **Kimi K2 (cloud)**
- Why: Multi-variable analysis, probabilistic modeling, tradeoff synthesis

---

**Example 2: Low Complexity (Local)**
```
@finance what's our burn rate?
```

**Router Decision:**
- Complexity score: **0.09** (low)
- Matched: `needs_reasoning:low`
- Decision: `workshop_simple_local`
- Model: **Qwen 9B (local)**
- Why: Simple lookup, no synthesis needed

---

**Example 3: Medium Complexity (Confidence Loop)**
```
@finance estimate runway if we reduce burn by 15%
```

**Router Decision:**
- Complexity score: **0.42** (medium)
- Matched: `needs_reasoning:medium`
- Decision: `workshop_confidence_loop`
- Algorithm: **Confidence escalation**
- Flow:
  1. Try local 9B first
  2. Self-verify confidence score
  3. If confidence < 0.8 → escalate to Kimi K2
  4. Return best result

---

## 2. Confidence Loop (Self-Verify Escalation) 🔁

### What It Does
Tries the **cheaper local model first**, asks it to self-assess confidence, and **escalates to cloud if uncertain**.

### How It Works
```yaml
- name: workshop_confidence_loop
  priority: 550
  rules:
    - type: complexity
      name: needs_reasoning:medium
  modelRefs:
    - model: Qwen3.5-9B-NoThinking  # Try first
    - model: accounts/fireworks/models/kimi-k2p6  # Escalate if needed
  algorithm:
    type: confidence
    confidence:
      confidence_method: self_verify
      threshold: 0.8  # Escalate if confidence < 80%
      escalation_order: cost  # Try cheap → expensive
      cost_quality_tradeoff: 0.3
```

**Self-Verify Prompt:**
```
After answering, rate your confidence 0-1:
- 1.0 = certain, factual
- 0.5 = uncertain, need more reasoning
- 0.0 = guessing
```

### Workshop Demo

**Example: Retention Probability Estimate**
```
@finance What's the probability Sarah Kim stays if we offer 15% raise vs 0.5% equity refresh?
```

**Confidence Loop Flow:**

**Pass 1: Local 9B**
```
Response: "Based on typical retention patterns, 15% raise → ~75% retention, 
          equity refresh → ~60% retention."
Confidence: 0.62 ❌ (below 0.8 threshold)
```

**Pass 2: Cloud Kimi K2 (Escalated)**
```
Response: "Based on retention_history.csv, for senior engineers with 2-3 years tenure:
          - 15% raise: 78% retention (95% CI: 71-85%)
          - 0.5% equity: 64% retention (95% CI: 55-73%)
          Recommendation: 15% raise (higher confidence interval)"
Confidence: 0.91 ✅ (above threshold)
```

**Final Decision:**
- Used: **Cloud model** (escalated)
- Cost: $0.30 (cloud tokens)
- Benefit: Higher accuracy with confidence intervals

---

**Cost Analysis:**
| Scenario | Local Only | Cloud Only | Confidence Loop |
|----------|------------|------------|-----------------|
| Simple queries (70%) | ✅ $0.01 | ❌ $0.30 | ✅ $0.01 (no escalation) |
| Medium queries (20%) | ⚠️ Low accuracy | ✅ High accuracy | ✅ $0.31 (escalated 50%) |
| Complex queries (10%) | ❌ Wrong | ✅ Correct | ✅ $0.30 (always escalate) |
| **Avg Cost/Query** | $0.01 | $0.30 | **$0.06** (5x savings) |

---

## 3. Domain Classification (MMLU-Style) 📚

### What It Does
Uses a **14-category MMLU classifier** to categorize queries by domain (law, computer science, finance, etc.) even without explicit keywords.

### How It Works
```yaml
domains:
  - name: "law"
    mmlu_categories: ["jurisprudence", "professional_law", "international_law"]
  - name: "computer_science"
    mmlu_categories: ["computer_security", "machine_learning", "college_computer_science"]
  - name: "finance"
    mmlu_categories: ["econometrics", "business_ethics", "microeconomics"]
```

### Workshop Demo

**Example: Legal Query Without Keywords**
```
@legal Can we require candidates to sign non-competes during hiring?
```

**Router Decision:**
- Keyword match: ❌ None (no "GDPR", "compliance", "regulation")
- Domain classification: ✅ **law** (95% confidence)
- Decision: `workshop_legal_cloud`
- Model: **Kimi K2 (cloud)**
- Why: Domain classifier caught legal topic despite no explicit keywords

---

**Example: R&D Query Without Keywords**
```
@rnd How would you build a recommendation system for 100M users?
```

**Router Decision:**
- Keyword match: ❌ None (no "design", "architecture", "ML pipeline")
- Domain classification: ✅ **computer_science** (92% confidence)
- Decision: `workshop_rnd_cloud`
- Model: **Kimi K2 (cloud)**
- Why: Semantic understanding of CS problem

---

**Fallback Protection:**
Combining keywords + domain ensures:
- **Keywords**: Fast, explicit matching ("GDPR" → legal)
- **Domain**: Catches semantic queries without buzzwords

---

## 4. Context-Based Routing (Token Count) 📏

### What It Does
Routes queries with **8K+ tokens** to cloud (local model can't fit in context).

### How It Works
```yaml
context:
  - name: large_context
    min_tokens: 8K
    max_tokens: 262K
```

### Workshop Demo

**Example: Long Meeting Transcript**
```
@ops-audio Transcribe this 2-hour exec meeting, then:
1. Summarize key strategic decisions
2. Extract all budget commitments
3. Identify risks mentioned
4. Create action items with owners

[Attach: exec_meeting_2hr.mp3]
→ Whisper transcription: 18,243 tokens
```

**Router Decision (Without Context Routing):**
- Modality: `audio_file` → Local 9B
- Problem: ❌ **Context overflow** (9B model window: 256K, but 18K transcript + 10K analysis prompt = tight fit)

**Router Decision (With Context Routing):**
- Step 1: Audio file → Local Whisper transcription (PII-safe)
- Step 2: Detect transcript size: **18,243 tokens**
- Step 3: Match `large_context` signal
- Decision: `workshop_large_context_cloud` (priority 850)
- Model: **Kimi K2 (262K context window)**
- Why: Long transcript needs cloud capacity

---

**Token Threshold Rationale:**
| Context Size | Model | Headroom | Best For |
|--------------|-------|----------|----------|
| < 8K tokens | Local 9B | 248K free | Normal queries, short docs |
| 8K-100K tokens | Cloud Kimi K2 | 162K free | Long meetings, multi-doc RAG |
| 100K+ tokens | Cloud Kimi K2 | 162K free | Entire codebases, books |

---

## 5. Feedback Detection (User Correction) 💬

### What It Does
Detects when users are **dissatisfied** with an answer and need re-routing or escalation.

### How It Works
```yaml
feedback_detector:
  enabled: true
  threshold: 0.7
  categories:
    - "dissatisfied"      # "That's wrong", "Not what I asked"
    - "needs_clarification"  # "I meant...", "Specifically..."
    - "request_different"    # "Try again", "Use a different approach"
```

### Workshop Demo

**Example: Escalation After Bad Local Answer**

**Turn 1: Initial Query (Local)**
```
User: @finance estimate our Series B dilution
Router: Complexity score 0.38 → Medium → Confidence loop
        Local 9B tries first
        Confidence: 0.74 (below 0.8 threshold)
        Escalates to cloud? No, close enough
Response: "Typically 15-25% dilution in Series B"
```

**Turn 2: User Feedback**
```
User: That's too generic. I need actual numbers for our cap table.
Router: Feedback detection → "dissatisfied" (confidence 0.89)
        Override: Force cloud routing
Decision: workshop_finance_complex_cloud
Model: Kimi K2
Response: "Based on cap_table.csv:
          - Current fully diluted: 10M shares
          - Series B: $40M at $160M pre → 20% dilution
          - New fully diluted: 12.5M shares
          - Your 8% becomes 6.4%"
```

---

**Feedback Categories:**
| User Says | Detected As | Action |
|-----------|-------------|--------|
| "That's wrong" | dissatisfied | Re-route to cloud, add correction context |
| "I meant X, not Y" | needs_clarification | Re-run with clarified intent |
| "Try a different way" | request_different | Change algorithm/model |
| "Perfect, thanks!" | satisfied | Cache result, no action |

---

## Workshop Challenge: Advanced Routing Scenarios

### Challenge 1: Confidence Loop Cost Savings
**Setup:** Finance team asks 100 queries/day, 70% simple, 20% medium, 10% complex.

**Task:** Calculate daily cost with:
1. All-cloud routing: $30/day (100 * $0.30)
2. All-local routing: $1/day (100 * $0.01) but 30% wrong answers
3. Confidence loop: ?

**Expected:**
- Simple (70): Local only = $0.70
- Medium (20): 50% escalate = $3.10
- Complex (10): Always escalate = $3.00
- **Total: $6.80/day (77% savings vs all-cloud)**

---

### Challenge 2: Domain Classification Blind Spot
**Task:** Find a finance query that:
- Does NOT contain finance keywords
- DOES trigger domain classifier
- Tests semantic understanding

**Example:**
```
@finance How much runway do we lose if headcount grows 30% next quarter?
```

- Keywords: ❌ No "burn rate", "runway", "dilution"
- Domain: ✅ Finance (econometrics category)
- Complexity: Medium → Confidence loop

---

### Challenge 3: Context Overflow Prevention
**Task:** Design a query that hits context limits:
1. Start with small query → local
2. Add iterative context → grows to 8K+ tokens
3. Triggers context-based escalation

**Example:**
```
@legal Review this vendor contract for GDPR compliance
[Attach: 45-page vendor_agreement.pdf]
→ PDF OCR: 12,847 tokens
→ Context signal triggered
→ Routes to cloud despite starting as "legal review" (would normally be cloud anyway)
```

---

### Challenge 4: Multi-Signal Prioritization
**Query:**
```
@finance For employee Sarah Kim (sarah@company.com, salary $180K), 
model equity dilution in Series B at $40M raise with 1x vs 2x liquidation preferences.
Include waterfall analysis and retention probability if she gets 0.5% refresh.
```

**Signals Detected:**
1. PII: `employee_pii` (name, email, salary) → Priority 1000
2. Finance modeling: `finance_modeling_keywords` → Priority 600
3. Complexity: `needs_reasoning:high` (0.68 score) → Priority 600
4. Multi-step: `multi_step_analysis` (waterfall) → Priority 600

**Router Decision:**
- Winner: **PII (priority 1000)** → Local
- Blocked: Finance complexity routing (lower priority)
- Correct: PII must be redacted first before cloud routing

**Multi-Pass Workflow (Agent-Level):**
1. **Local 9B**: Detect PII, redact → `[EMPLOYEE_A], [EMAIL_REDACTED], [SALARY_NORMALIZED]`
2. **Cloud Kimi K2**: Complex dilution math with anonymized data
3. **Local 9B**: Restore PII, add privacy disclaimer

---

## Advanced Routing Priority Stack

```
Priority 1000: PII/Jailbreak         → Local (security override)
Priority  900: Audio/Vision files    → Local (multimodal privacy)
Priority  850: Large context (8K+)   → Cloud (capacity limit) [ADVANCED]
Priority  800: Legal research        → Cloud + domain:law [ADVANCED]
Priority  700: R&D design            → Cloud + domain:cs [ADVANCED]
Priority  650: Long query (400+ words) → Cloud [ADVANCED]
Priority  600: Finance complex       → Cloud + domain:finance + complexity:high [ADVANCED]
Priority  550: Medium complexity     → Confidence loop (try local → escalate) [ADVANCED]
Priority  500: Simple queries        → Local + complexity:low [ADVANCED]
Priority  100: Default               → Local (fallback)
```

**🔑 Key Insight:** Advanced features add **4 new routing layers** (850, 650, 550, complexity enhancements) that handle edge cases keyword matching misses.

---

## Observability: Viewing Router Decisions

**TUI Output:**
```
🧭 router → Kimi-K2p6 | decision=workshop_confidence_loop (conf 0.91) | 
complexity=needs_reasoning:medium | domain=finance | escalated=true | iters=2
```

**Breakdown:**
- `decision=workshop_confidence_loop` - Triggered confidence algorithm
- `conf 0.91` - Final confidence score (post-escalation)
- `complexity=needs_reasoning:medium` - MMBERT score [ADVANCED]
- `domain=finance` - MMLU classification [ADVANCED]
- `escalated=true` - Local tried first, escalated to cloud [ADVANCED]
- `iters=2` - Ran 2 models (local + cloud) [ADVANCED]

---

## Summary: When to Use Each Feature

| Feature | Best For | Workshop Agent |
|---------|----------|----------------|
| **MMBERT Complexity** | Semantic difficulty scoring | Finance multi-scenario, R&D design |
| **Confidence Loop** | Cost optimization on medium queries | Finance retention modeling |
| **Domain Classification** | Queries without explicit keywords | Legal (no "GDPR"), R&D (no "design") |
| **Context Routing** | Large documents, long transcripts | ops-audio (2hr meetings) |
| **Feedback Detection** | Iterative refinement, user corrections | Any agent with multi-turn dialogue |

**💡 Workshop Positioning:**
- **Basic Workshop**: Keyword-based routing (deterministic, easy to explain)
- **Advanced Workshop**: Add ML features (shows router intelligence, not just rules)

**Suggested Flow:**
1. Demo basic keyword routing first (HR, Finance, R&D)
2. Show "blind spot" query that keywords miss
3. Introduce domain classification to catch it
4. Show confidence loop saving costs
5. Finale: Multi-signal query with priority override (PII beats everything)

This progression shows the router evolving from "simple rules" to "intelligent ML system" while maintaining the core workshop narrative.