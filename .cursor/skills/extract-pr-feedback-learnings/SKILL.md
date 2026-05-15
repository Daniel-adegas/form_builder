---
name: extract-pr-feedback-learnings
description: >-
  Analyzes pull request comments and extracts reusable Salesforce DX engineering learnings by
  theming feedback, spotting repeated patterns, and mapping outcomes to Cursor rules, skills, or
  subagent guidance—without modifying rules unless the human approves. Use when consolidating PR
  review feedback into documentation, retrospectives, or updates to `.cursor/rules`, `.cursor/skills`,
  `.cursor/agents`, or `.cursor/commands`; when the user pastes exported PR discussions or asks to
  turn review comments into team standards or agent instructions.
disable-model-invocation: true
---

# Extract PR feedback learnings

## Purpose

Analyze pull request comments and extract reusable engineering learnings for this Salesforce DX project.

Convert repeated PR feedback into better Cursor rules, skills, or subagent instructions.

## Workflow

1. Read PR comments
2. Group comments by theme:
   - regression risk
   - LWC architecture
   - Apex usage
   - Salesforce security
   - tests
   - naming
   - metadata
   - permissions
   - performance

3. Ignore one-off subjective comments
4. Identify repeated patterns
5. Convert repeated feedback into reusable guidance
6. Suggest which rule, skill, or subagent should be updated
7. Never update rules automatically without human approval

## Output format

- Feedback pattern
- Why it matters
- Suggested rule update
- Suggested skill update
- Suggested subagent update
- Confidence: low / medium / high

## Important

Only suggest learnings that are reusable across future work.

Do not create rules from isolated opinions.

Do not weaken existing standards.

Do not remove safety checks.
