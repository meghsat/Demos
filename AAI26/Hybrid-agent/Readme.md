# Startup AI Router Workshop - Agent Skills

This directory contains **high-level skill definitions** for the Semantic Router startup workshop. Each skill provides **rules and constraints** that guide the Openclaw agent's behavior

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
   - Routing constraints ("never send PII to cloud")
   - Data source pointers ("read employees.csv")
   - Output expectations ("include privacy disclaimer")
   - Operation guidelines ("soft delete, don't hard delete")

---

## Agent Skills (6 Total)

### 1. **HR** ([hr.md](agents/hr.md))
- **Handles**: Employee management, benefits questions
- **Data**: `employees.csv`, `benefits_handbook.md`
- **Routing**: Local (PII-sensitive) - Handled by Semantic Router

**Example**:
```
@hr onboard Maya Chen, Senior AI Engineer, starts July 1, 
salary $175K, equity 0.8%, email maya.chen@scudfer.rc
```

---

### 2. **Finance** ([finance.md](agents/finance.md))
- **Handles**: Burn rate, equity modeling, retention analysis
- **Data**: `financials.csv`, `cap_table.csv`, `employees.csv`, `retention_history.csv`

**Examples**:
```
@finance what's our current burn rate and runway?

@finance For Maya Chen's 0.8% equity grant, model dilution 
in Series B at $40M raise on $160M pre-money. Include 
waterfall scenarios for 1x, 1.5x, 2x preferences.
```

---

### 3. **Legal** ([legal.md](agents/legal.md))
- **Handles**: Regulatory research, contract review
- **Data**: None (web search for regulations, uploaded contracts)

**Examples**:
```
@legal What are latest GDPR requirements for AI products 
processing EU user data? Include DPA clauses and recent cases.

@legal Review this vendor NDA for unusual terms
[Attach: vendor_nda.pdf]
```

---

### 4. **R&D** ([rnd.md](agents/rnd.md))
- **Handles**: System design, ML architectures, infrastructure planning
- **Data**: None (greenfield design, no existing codebase)
- **Core Rules**:
  - Novel system design only (not modifying existing code)
  - Complete proposals: architecture + infrastructure + roadmap + costs
  - Production-ready designs
  - Cite sources (papers, frameworks, similar systems)

**Example**:
```
@rnd Design a fraud detection ML pipeline for fintech 
transactions. Propose architecture, models, and infrastructure.
```

---

### 5. **Operations - Audio** ([ops-audio.md](agents/ops-audio.md))
- **Handles**: Meeting transcription, decision extraction
- **Data**: Uploaded audio files (MP3, WAV, M4A)
- **Modality**: Audio
- **Core Rules**:
  - Extract: decisions, action items, budget concerns

**Example**:
```
@ops-audio Transcribe this exec meeting and extract key 
decisions, action items, and budget concerns.
[Attach: meeting.mp3]
```

---

### 6. **Operations - Vision** ([ops-vision.md](agents/ops-vision.md))
- **Handles**: Dashboard analysis, chart trend identification
- **Data**: Uploaded images (PNG, JPG screenshots)
- **Modality**: Vision
- **Core Rules**:
  - Use OCR + chart recognition
  - Identify trends, flag issues by severity
  - Correlate related metrics

**Example**:
```
@ops-vision Analyze this metrics dashboard and identify 
concerning trends in retention and revenue.
[Attach: dashboard.png]
```

---

## Dummy Data Files

Located in `../data/`:

| File | Records | Purpose |
|------|---------|---------|
| `employees.csv` | 12 employees | HR operations, finance retention |
| `financials.csv` | 5 months | Burn rate, runway calculations |
| `cap_table.csv` | 4 classes | Equity dilution modeling |
| `retention_history.csv` | 7 quarters | Retention probability modeling |
| `benefits_handbook.md` | 10 sections | HR RAG source |
