---
name: create-lwc-feature
description: >-
  Designs and implements maintainable Salesforce LWC features: LDS and UI API
  first, Apex only when necessary, standard lightning components, full UI
  states, focused small components, meaningful names, Jest tests, and impact
  analysis before touching shared code. Use when building or extending LWCs,
  Salesforce frontend features, form or record UI, or when the user names this
  skill or asks for LWC feature work aligned to project standards.
disable-model-invocation: true
---

# Create LWC feature

Create maintainable Salesforce LWC features following project standards.

Requirements:

- Prefer LDS and UI API first
- Use Apex only when necessary
- Use standard lightning components
- Handle loading, empty, success, and error states
- Keep components focused
- Avoid large components
- Use meaningful names
- Add Jest tests
- Analyze impact before modifying shared code
- For new builder features, check whether similar features use `Form_Builder_Settings__c` (or project feature service) and mirror that gating pattern.
- Add Jest that covers the primary user/data path (events, wires, or Apex mocks), not placeholder `expect(1).toBe(1)

## Data and backend

1. **Order of preference**: Lightning Data Service (`lightning-record-*`, `getRecord`, etc.) → UI API / wire adapters → imperative Apex only when the above cannot satisfy the requirement.
2. **Apex**: Thin controllers; shared logic in services; `with sharing` or `inherited sharing` unless justified; CRUD/FLS and bulk-safe patterns when accessing data.
3. **Do not** add Apex for what LDS, UI API, formulas, flows, or validation rules can cover.

## UI

- Prefer `lightning-*` primitives and SLDS conventions.
- Expose a small, stable public API (`@api`); document event names and payloads if components communicate upward.

## States

For user-visible work, plan and implement:

- **Loading**: spinners or skeletons; disable destructive actions while pending where appropriate.
- **Empty**: intentional empty copy or placeholders, not a silent blank.
- **Success**: clear completion feedback when the UX requires it (save, submit, copy).
- **Error**: user-facing message; include enough detail for support without leaking sensitive internals.

## Structure and naming

- One main concern per component; extract child components or JS modules when a file grows or responsibilities diverge.
- Use full words and consistent domain language (English identifiers).
- Avoid duplicated state; do not mutate wired data in place.

## Shared and existing code

Before changing shared utilities, base components, Apex services, or widely used patterns:

- Run the workflow in [pre-change-impact-analysis](../pre-change-impact-analysis/SKILL.md) (search consumers, events, `@api`, tests).
- Prefer minimal, backward-compatible edits; do not rename public surfaces without updating all references.

## Testing

- Add or update Jest tests with the feature: render paths, interactions, emitted events, and loading / error mocks (wire adapters, LDS, Apex as appropriate).
- For Apex added or changed in the same effort, include or update Apex tests per project standards.

## After delivery

Summarize files touched, residual regression risks, and which Jest and Apex tests to run.
