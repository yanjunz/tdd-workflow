---
name: "TDD: New"
description: Start new feature TDD workflow — interactive requirements gathering, create spec directory
category: TDD Workflow
tags: [tdd, workflow, new-feature]
---

Start new feature TDD workflow.

**Input**: Parameter after `/tdd:new` is the feature name (kebab-case), or a description of the feature.

**Steps**

1. **If no parameter, ask user what they want to build**

   Use **AskUserQuestion** tool (open-ended, no preset options):
   > "What feature do you want to implement? Please describe your requirements."

   Derive kebab-case name from description (e.g., "refund retry fix" -> `refund-retry-fix`).

   **Important**: Do not proceed until user's requirements are understood.

2. **Interactive requirements gathering (all dimensions must be completed)**

   Ask questions round by round, reflecting understanding back to user for confirmation after each round:

   | Dimension | Question |
   |-----------|----------|
   | Target users | Who will use this? (based on actual project roles) |
   | Core scenarios | Top 1-3 most important use cases? |
   | Input/Output | What is input? What is returned? |
   | Error handling | What situations fail? Expected error behavior? |
   | Scope boundaries | What is explicitly NOT in scope? |
   | Acceptance criteria | How do we know it's done? |

3. **After scope is confirmed, create spec directory**

   ```bash
   mkdir -p tdd-specs/<name>
   echo "<name>" > tdd-specs/.current
   ```

4. **Stop, wait for user direction**

**Output**

- Feature name and path: `tdd-specs/<name>/`
- Requirements confirmation summary (user stories + acceptance criteria)
- Prompt:
  > "Requirements confirmed! Run `/tdd:ff` to generate all spec docs at once, or `/tdd:spec` for step-by-step confirmation."

**Guardrails**
- Do not create any spec files, only create directory
- Scope must be confirmed by user before proceeding
- If feature name already exists, suggest using `/tdd:continue` to resume
