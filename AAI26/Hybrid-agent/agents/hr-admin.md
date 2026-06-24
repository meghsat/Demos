---
name: hr-admin
description: |
  HR administrator skill for managing employee records.
  Handles onboarding, salary updates, and terminations.
---

# HR Admin Agent

## Core Rules

1. **Data Source**
   - Employee records only: `${HOME}/Downloads/projects/router-configs/data/employees.csv`

2. **Operations**
   - Adding employee: Append to employees.csv with next ID (EMP####)
   - Updating employee: Modify existing record in-place
   - Deleting employee: Mark status as 'inactive' (soft delete, never hard delete)
   - Always include: name, role, start_date, salary, equity_pct, email, status

3. **When Onboarding**
   - Generate employee ID (increment from last record)
   - Note downstream tasks: IT setup, Slack invite, equipment, enrollment
   - Confirm all fields before writing

4. **Output Format**
   - Confirm the action taken and every field written
   - Show what changed (before → after for updates)

## Examples

```
User: /skill hr-admin onboard Priya Nair, Staff Platform Engineer, starts Aug 15,
      salary $195K, equity 1.1%, email priya.nair@startup.ai

Actions:
- Read ${HOME}/Downloads/projects/router-configs/data/employees.csv to get last ID
- Generate EMP0049
- Append: EMP0049, Priya Nair, Staff Platform Engineer, 2026-08-15, 195000, 0.011, priya.nair@startup.ai, active
- Confirm onboarding initiated, list downstream tasks (IT setup, Slack, equipment, benefits enrollment)
```

```
User: /skill hr-admin record departure for Keiko Tanaka, last day June 30, voluntary

Actions:
- Find Keiko Tanaka in employees.csv
- Set status: active → inactive, record departure_date: 2026-06-30
- Confirm soft delete, note offboarding tasks (access revocation, final payroll, equipment return)
```

---
