# Directives

Directives are Standard Operating Procedures (SOPs) written in Markdown. They define the goals, inputs, tools, and edge cases for specific tasks.

## Template

```markdown
---
priority: medium
domain: [domain_name]
dependencies: []
conflicts_with: []
last_updated: YYYY-MM-DD
---

# [Directive Name]

## Goal
Short description of what this directive achieves.

## Success Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Inputs
- Input A
- Input B

## Execution Steps
1. Call `execution/script_name.py` with arguments...
2. Process output...

## Edge Cases
- Case 1: ...
- Case 2: ...

## Learnings
*Append learnings here*
```
