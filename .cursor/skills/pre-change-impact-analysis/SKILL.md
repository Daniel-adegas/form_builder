---
name: pre-change-impact-analysis
description: >-
  Before changing code, maps LWC and Apex dependencies, event and field usage,
  shared utilities, regression risk, and post-change tests. Use when editing or
  refactoring LWCs, Apex, shared modules, or metadata; when the user asks for
  impact analysis, dependency review, or regression checks; or before any
  non-trivial code change in Salesforce DX projects.
disable-model-invocation: true
---

# Pre-change impact analysis

## Principle

Before modifying code, analyze all dependencies, references, shared logic, and possible regressions.

## Workflow

Execute in order. Use repository search (semantic and exact) until each item is satisfied or explicitly marked not applicable.

1. Identify affected LWC components
   - Map the component(s) under change, parents that `import`/embed them, and children they compose.
   - Note any `@api`, public getters, or slot usage that other components rely on.

2. Identify Apex dependencies
   - Find Apex classes/methods called from LWCs (`@AuraEnabled`, imperative calls, wires).
   - Find other Apex callers of the same methods or services (controllers, batch, tests).

3. Search event consumers
   - Find `CustomEvent` / `dispatchEvent` names and `addEventListener` / `on*` handlers in template or JS.
   - Track both publishers and subscribers across the codebase.

4. Search field usages
   - For Salesforce: API names in LWC (`@wire`, `getRecord`, forms), Apex SOQL/DML, validation rules, flows, and tests.

5. Identify shared utilities
   - Locate reused JS modules, Apex services, labels, and design tokens touched by the change path.

6. Evaluate regression risks
   - List what can break: other screens, layouts, permission-sensitive paths, bulk behavior, and backward compatibility of public APIs.

7. Prefer minimal isolated changes
   - Choose the smallest change that meets the goal; avoid drive-by refactors and unrelated files.

8. Recommend tests after implementation
   - Name Jest cases (LWC) and Apex tests to add or update, including scenarios that would have caught the original issue.

## Output

After analysis (and again after implementation if the skill was used for a change), summarize:

- **Scope**: What was/will be touched.
- **Dependencies**: LWCs, Apex, events, fields, shared utilities (concise list).
- **Regression risks**: Ranked or grouped by severity.
- **Tests**: Specific tests to run or write.

Use the project’s existing standards for security (sharing, CRUD/FLS), bulkification, and UI states where relevant.
