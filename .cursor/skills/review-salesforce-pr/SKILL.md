---
name: review-salesforce-pr
description: >-
  Reviews Salesforce pull requests for stability, maintainability, and regression
  prevention (LWC, Apex, metadata, tests). Use when reviewing PRs or diffs in
  Salesforce DX repos, before merge, or when the user asks for a Salesforce PR
  review, sanity check, or risk assessment.
disable-model-invocation: true
---

# Review Salesforce pull request

## Goals

Prioritize **stability**, **maintainability**, and **regression prevention** over stylistic preferences unless style violations hide real bugs.

## Workflow

1. **Scope the diff** — List changed paths: LWC, Apex, tests, flows, permission sets, labels, `lwc-jest` config, etc.
2. **Trace blast radius** — For each changed symbol, search consumers (repo-wide): imports, templates, `c/` tags, Apex callers, wires, imperative Apex.
3. **Classify changes** — Bugfix, feature, refactor, chore. Refactors mixed with behavior fixes get extra scrutiny.
4. **Run the review checklist** — Work top to bottom; cite file paths and line ranges when flagging issues.
5. **Summarize** — Blocking vs non-blocking, test gaps, and merge recommendation.

## Review checklist

- Check for regression risks
- Identify shared code modifications
- Verify Apex consumers
- Verify LWC public APIs
- Verify event payload compatibility
- Check CRUD/FLS concerns
- Check SOQL/DML inside loops
- Verify Jest test impact
- Verify Apex test impact
- Prefer minimal changes
- Flag risky refactors

## What to verify (per item)

| Checklist item              | What to do                                                                                                                                                                                                         |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Regression risks            | Call out layout/flow breakages, permission-sensitive paths, empty/error/loading states, bulk/async callers, and backward compatibility.                                                                            |
| Shared code modifications   | Flag edits to shared LWCs, Apex services, utilities, labels, or design tokens; list dependents if not obvious from the PR.                                                                                         |
| Apex consumers              | Grep or search for `@AuraEnabled` methods and classes; confirm LWCs, other Apex, Flow actions, and tests still match signatures and return shapes.                                                                 |
| LWC public APIs             | Check `@api` renames, type/default changes, required vs optional, and parent components passing props; flag breaking contract changes.                                                                             |
| Event payload compatibility | Match `CustomEvent` names and `detail` shapes to all publishers and subscribers; flag renames or structural changes without migration.                                                                             |
| CRUD/FLS                    | In Apex with user data: `with sharing` / `inherited sharing` as appropriate, `Security.stripInaccessible`, or explicit enforced CRUD/FLS per team standard; call out dangerous `without sharing` and dynamic SOQL. |
| SOQL/DML inside loops       | Flag queries and DML in loops, unbulkified handlers, and N+1 patterns; suggest bulkification or collection-based DML.                                                                                              |
| Jest test impact            | Note changed components without test updates, brittle DOM assertions, missing mocks for new wires/Apex, and missing interaction/event tests for new behavior.                                                      |
| Apex test impact            | Coverage on new/changed logic, positive and negative paths, bulk tests (200+ rows) where relevant, `SeeAllData=false` assumptions, and org-specific data dependencies.                                             |
| Minimal changes             | Praise small diffs; question unrelated files, drive-by formatting, and scope creep.                                                                                                                                |
| Risky refactors             | Large renames, “cleanup” in hot paths, behavior changes disguised as refactor, and shared API changes without a compatibility story.                                                                               |
| Picklist/metadata alignment | Restricted picklist API values match Apex, LWC, tests, and field XML; defaults cannot use display-only casing.                                                                                                     |
| LWC handler binding         | Child templates calling parent logic use events or documented patterns; flag `@api` function props used as DOM handlers when parent state is required.                                                             |
| Multi-mode UI               | Rendering guards account for **all** layout/mode variants (duplicate nav/progress chrome).                                                                                                                         |
| Accessibility               | New dialogs, progress UX, and live regions meet baseline ARIA; validation is not toast-only on Experience Cloud without verification.                                                                              |
| Performance (LWC)           | Flag hot getters (e.g. repeated parse/stringify), uncleared timers on unmount, and unguarded `renderedCallback` work on every re-render.                                                                           |
| LWC template directives     | Flag deprecated `if:true` / `if:false`; require `lwc:if` / `lwc:else` (LWS-safe). Migrate whole touched templates, especially sibling `formRendererLayout*` bundles.                                               |
| LWC DOM access              | Prefer `lwc:ref` over `template.querySelector` for stable nodes; flag silent-break selectors in large bundles (`formBuilderVisual`).                                                                               |
| SLDS / styling              | Flag hard-coded hex/rgba and inline `style` colors; prefer design tokens in bundle CSS.                                                                                                                            |
| Metadata hygiene            | New/changed custom fields need `<description>`; toggles on `Form_Builder_Settings__c` document gated UI. Layout Mode on `C_Form__c` is form config — not a settings toggle (see project rule).                     |
| Query selectivity (Apex)    | Flag wide multi-field `OR` queries, non-indexed hot filters, and undocumented single-slice attachment (e.g. deps on page 1 only).                                                                                  |
| Form Builder security model | Do not block metadata-read SOQL solely for missing `WITH USER_MODE` when Permission Sets + sanctioned readers apply; still flag user-data paths and new `without sharing`.                                         |

## Feedback severity

Use consistent labels so authors can triage:

- **Blocking** — Likely production bug, security/share issue, broken contract, or missing critical tests for risky behavior.
- **Should fix** — Meaningful risk or maintainability debt; merge acceptable only with documented follow-up if team allows.
- **Suggestion** — Optional improvement; not required for merge.

## Output template

```markdown
## Summary

[1–3 sentences: intent of PR + overall risk]

## Checklist results

- Regression risks: [pass / concerns: …]
- Shared code: [none / list]
- Apex consumers: [verified / gaps]
- LWC @api: [compatible / breaking: …]
- Events: [compatible / breaking: …]
- CRUD/FLS: [ok / issues]
- SOQL/DML loops: [ok / issues]
- Jest: [ok / gaps]
- Apex tests: [ok / gaps]
- Change size: [minimal / concerns]
- Refactors: [safe / risky: …]

## Findings

### Blocking

- …

### Should fix

- …

### Suggestions

- …

## Recommended tests

- [Commands or named tests to run before merge]
```

## Related

When implementing fixes from review feedback, use **pre-change impact analysis** (`.cursor/skills/pre-change-impact-analysis/SKILL.md`) before editing shared or high-risk code.
