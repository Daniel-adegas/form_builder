---
name: sync-pr-comments-to-agent-improvements
description: >-
  Fetches or reads GitHub pull request comments, filters for actionable engineering feedback, maps
  repeated patterns to project rules, skills, or subagent instructions, and proposes exact repo
  changes for human approval—preferably on a separate PR. Use when turning PR review threads into
  updates under `.cursor/rules`, `.cursor/skills`, `.cursor/agents`, or related Cursor config; when
  the user names a PR or asks to sync review feedback into agent configuration; or after a merge
  when consolidating learnings into versioned Cursor metadata.
disable-model-invocation: true
---

# Sync PR comments to agent improvements

## Workflow

1. Fetch or read PR comments
2. Identify actionable engineering feedback
3. Ignore resolved noise, personal preference, and one-off comments
4. Extract repeated patterns
5. Map each pattern to:
   - project rule
   - skill
   - subagent instruction

6. Propose exact changes
7. Ask for approval before applying changes
8. Prefer opening a separate PR for agent/rule improvements

## How to fetch (GitHub)

Prefer non-interactive tools the user already has:

- `gh pr view <number> --comments` and `gh api repos/{owner}/{repo}/pulls/<number>/comments` for review comments
- `gh api repos/{owner}/{repo}/issues/<number>/comments` for issue-style comments on the PR
- If the user pastes exports (markdown, JSON), parse those instead

Treat **resolved review threads**, emoji-only reactions, and **duplicate “+1”** repeats as low signal unless they restate a concrete engineering requirement.

## What counts as actionable

Include feedback that is **specific**, **repeatable**, and **tied to correctness, security, tests, regressions, APIs, or team conventions**.

Deprioritize or skip:

- Taste without engineering impact (formatting nitpicks already covered by formatters)
- One-off context that will not recur
- Requests that belong only to that PR’s business logic unless they reveal a missing guardrail

## Repeated patterns

A pattern is **candidate configuration** only when it appears **across multiple comments or multiple PRs**, or when a **single comment** states a clear **policy** (e.g., “never mutate wired LDS data”) that should hold for all future work.

**Never add broad rules based on one PR only.**

## Mapping deliverables

For each accepted pattern, specify:

| Field          | Content                                                                                 |
| -------------- | --------------------------------------------------------------------------------------- |
| Target         | Path under `.cursor/rules/`, `.cursor/skills/<name>/SKILL.md`, or `.cursor/agents/*.md` |
| Change type    | New file, new section, or surgical edit to existing text                                |
| Exact proposal | Copy-paste-ready markdown or unified diff for the target file                           |
| Rationale      | One or two sentences tied to review evidence (cite comment author/summary, not drama)   |
| Risk           | What could go wrong if misapplied                                                       |

Prefer **small targeted improvements** over large rewrites.

## Approval and application

**Never auto-apply learnings without review.**

1. Present the proposal as a short plan plus exact edits
2. Wait for explicit human approval to write files
3. After approval, apply edits mechanically—no rewording unless the user asked

**Prefer opening a separate PR for agent/rule improvements** so product code reviews stay focused.

Keep all agent improvements **versioned in the repository** (commit with the rest of the project).

## Safety rules

- Never auto-apply learnings without review
- Never remove regression-safety rules
- Never weaken testing requirements
- Never add broad rules based on one PR only
- Prefer small targeted improvements
- Keep all agent improvements versioned in the repository

## Final response requirements

After proposals (or after approved edits):

- Summarize patterns accepted vs rejected (with brief why)
- List files that would change or did change
- Note regression or guidance risks
- Suggest a smoke check (e.g., open relevant skill in Agent, run affected Jest/Apex if rules touched testing discipline)
