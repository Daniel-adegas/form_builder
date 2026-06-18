---
name: fix-lwc-bug-safely
description: >-
  Guides minimal, regression-safe fixes for existing Lightning Web Components:
  clarifies actual vs expected behavior, maps LWCs, Apex, and shared JS, keeps
  APIs stable, updates Jest, and surfaces risks. Use when fixing LWC bugs or
  incorrect behavior; when the user asks for a safe fix, minimal change, or
  regression avoidance; or when debugging Salesforce DX LWC features.
disable-model-invocation: true
---

# Fix LWC bug safely

## Principle

Correct the defect with the smallest change set; do not refactor unrelated code or expand scope.

## Workflow

1. Understand current behavior
2. Identify expected behavior
3. Search all related components
4. Search Apex integrations
5. Search shared utilities
6. Avoid unrelated refactors
7. Keep public APIs stable
8. Add or update Jest tests
9. Explain regression risks after changes

## Execution guidance

Apply the workflow in order using repository search (semantic and exact) until each step is done or marked not applicable.

- For steps 1–2: Reproduce or trace the code path (props, wires, handlers, conditional rendering); confirm expected behavior against requirements, Apex contracts, or tests, and note assumptions if unclear.
- For steps 3–5: Map parents that import or embed the LWC, composed children, `c-*` usage, `CustomEvent` publishers and subscribers, `@AuraEnabled` and `@wire` usage, other callers of the same Apex APIs, and shared JS modules, labels, or tokens on the change path.
- For steps 6–7: Touch only what the fix requires; preserve `@api` names and semantics, event `type` strings, and event detail shapes unless the user explicitly approves a breaking change (if breaking, enumerate consumers to update).
- For step 8: Prefer a Jest case that fails before the fix and passes after; update mocks for wires, Apex, or events.
- When fixing lifecycle or navigation bugs: verify all `setTimeout` / `setInterval` IDs are cleared in `disconnectedCallback`; check `renderedCallback` for missing early-exit guards.
- For step 9: List screens, integrations, and manual org checks worth smoking after deploy.

## Output

After implementation, summarize:

- **What changed**: Files and behavior delta (concise).
- **Why it fixes the bug**: Root cause, not only the symptom.
- **Tests**: Jest added or updated; suggested Apex or UI tests if relevant.
- **Regression risks**: What could still break and what to run manually in the org if needed.

Use the project’s Salesforce and LWC standards for LDS vs Apex, error and empty states, and security where applicable.
