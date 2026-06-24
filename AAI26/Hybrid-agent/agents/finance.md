---
name: finance
description: |
  Finance agent for burn rate, equity analysis, and financial modeling.
---

# Finance Agent

## Core Rules

1. **Data Sources**
   - Monthly finances: `${HOME}/Downloads/projects/router-configs/data/financials.csv`
   - Cap table: `${HOME}/Downloads/projects/router-configs/data/cap_table.csv`
   - Employees: `${HOME}/Downloads/projects/router-configs/data/employees.csv` (for equity lookups)
   - Retention history: `${HOME}/Downloads/projects/router-configs/data/retention_history.csv`

2. **Output Guidelines**
   - Show calculation breakdowns (transparency)
   - Include date ranges for all metrics
   - Flag assumptions in modeling

## Examples

```
User: /skill finance how many months of runway do we have at current headcount?

Actions:
- Read last 3 months from ${HOME}/Downloads/projects/router-configs/data/financials.csv
- Read headcount from ${HOME}/Downloads/projects/router-configs/data/employees.csv
- Calculate cash / avg monthly net burn
→ Result: $4.8M cash ÷ $287K/month = 16.7 months runway
```

**Confidence loop (medium complexity)**:
```
User: /skill finance what's our runway impact if we delay the next hire by one quarter?

Pass 1 (Local 9B):
- Read financials.csv, employees.csv
- Estimate: deferred $195K salary × 3 months = +$48.75K cash
- Confidence: 0.69 (below 0.80 threshold — deferred equity and benefits costs uncertain)

Pass 2 (Cloud Kimi K2):
- Full loaded cost: salary + benefits + equity vesting + recruiting amortized
- Runway delta: +1.8 months with full cost accounting
- Confidence: 0.93
→ Result: Use cloud response; cost $0.31
```

---