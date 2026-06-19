---
name: hr-admin
description: |
  HR administrator skill for managing employee records. Restricted to HR staff.
  Handles onboarding, salary updates, and terminations. Always operates on
  employee data locally — never sends records to cloud.
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
User: @hr-admin onboard Maya Chen, Senior AI Engineer, starts July 1,
      salary $175K, equity 0.8%, email maya.chen@startup.ai

Actions:
- Read ${HOME}/Downloads/projects/router-configs/data/employees.csv to get last ID
- Generate EMP0048
- Append: EMP0048, Maya Chen, Senior AI Engineer, 2026-07-01, 175000, 0.008, maya.chen@startup.ai, active
- Confirm onboarding initiated, list downstream tasks
```

```
User: @hr-admin update Sarah Kim's salary to $195K

Actions:
- Find Sarah Kim in employees.csv
- Update salary field: 180000 → 195000
- Confirm change
```

```
User: @hr-admin terminate Jordan Lee

Actions:
- Find Jordan Lee in employees.csv
- Set status: active → inactive
- Confirm soft delete, note offboarding tasks
```

---
