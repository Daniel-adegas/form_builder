---
name: github-pr-learning-workflow
description: >-
  Uses GitHub MCP (and CLI fallback) to read recent pull requests, review threads, and inline
  review feedback; extracts repeatable engineering patterns; maps them to existing or new Cursor
  rules, skills, and subagents; and proposes exact text changes for human approval only. Use when
  running a PR-review learning pass, consolidating feedback after merges, or improving `.cursor`
  configuration from GitHub discussions—without auto-editing files.
disable-model-invocation: true
---

# GitHub PR learning workflow

Use GitHub MCP to analyze pull request feedback and propose improvements to Cursor rules, skills, and subagents.

Always run these steps on PR reviews in order to learn.

## Workflow

1. Identify the current repository.
2. List recent pull requests.
3. Read PR comments, review comments, and discussion threads.
4. Extract actionable engineering feedback.
5. Ignore noise, personal preferences, outdated comments, and one-off opinions.
6. Group feedback by theme:
   - regression risk
   - LWC architecture
   - Apex usage
   - LDS/UI API usage
   - Salesforce security
   - Jest tests
   - Apex tests
   - metadata
   - permissions
   - performance

7. Detect repeated patterns across PRs.
8. Map each pattern to one of:
   - existing Cursor rule
   - existing skill
   - existing subagent
   - new rule needed
   - new skill needed

9. Propose exact text changes.
10. Ask for human approval before editing files.

## Repository identification

Resolve `owner` and `repo` for GitHub calls by, in order:

1. `git remote get-url origin` (or the primary remote) and parse `owner/repo`.
2. If ambiguous, ask the user for `owner` and `repo`.

## GitHub MCP (preferred)

Before any MCP call, read the tool descriptor schema under the workspace `mcps/user-github/tools/` folder, then invoke via `call_mcp_tool`.

Typical read path for a learning pass:

| Step                  | MCP tool                    | Purpose                                               |
| --------------------- | --------------------------- | ----------------------------------------------------- |
| List PRs              | `list_pull_requests`        | Recent PRs (`state`, `sort`, `direction`, pagination) |
| PR summary            | `get_pull_request`          | Title, body, state, metadata                          |
| Inline review threads | `get_pull_request_comments` | Line/file review comments                             |
| Review summaries      | `get_pull_request_reviews`  | Approved/changes requested bodies                     |

**PR conversation comments** (issue comments on the PR): this MCP server may not expose a list-comments reader. If conversation thread text is missing after the calls above, fall back once to:

`gh api repos/<owner>/<repo>/issues/<pull_number>/comments`

(or ask the user to paste exports). Never paste tokens or secrets into the chat.

## Inventory before mapping (step 8)

Search the repo for existing guidance targets:

- `.cursor/rules/` (`RULE.md`, `*.mdc`, or project conventions)
- `.cursor/skills/*/SKILL.md`
- `.cursor/agents/*.md`

Quote or summarize existing text only when proposing a delta; do not dump whole files unless needed for the proposal.

## Actionable vs noise (step 4–5)

**Prefer** feedback that is specific, repeatable, and tied to correctness, security, tests, regressions, APIs, Salesforce constraints, or team conventions.

**Deprioritize** resolved threads whose requirement is obsolete, emoji-only reactions, duplicate +1s, pure formatting taste covered by tooling, and one-off business logic unless it reveals a missing guardrail.

## Repeated patterns (steps 7–8)

A pattern is worth a **rule/skill/subagent** update only when:

- it appears across **multiple PRs** or **multiple independent comments**, or
- a **single** comment states a clear **policy** that should hold for all future work (for example: never mutate wired LDS data).

**Never add a permanent rule from a single isolated comment** that does not meet the bar above.

## Proposals (step 9)

For each accepted pattern, include:

| Field          | Content                                                                                 |
| -------------- | --------------------------------------------------------------------------------------- |
| Target         | Path under `.cursor/rules/`, `.cursor/skills/<name>/SKILL.md`, or `.cursor/agents/*.md` |
| Change type    | New file, new section, or surgical edit                                                 |
| Exact proposal | Copy-paste-ready markdown or unified diff                                               |
| Rationale      | One or two sentences tied to review evidence (no drama)                                 |
| Risk           | What could go wrong if misapplied                                                       |

Prefer **small, targeted improvements** over broad rewrites. Keep all proposed changes **versioned in the repository** (commit with the project).

## Safety constraints

- Never modify files automatically.
- Never weaken regression-safety rules.
- Never weaken testing rules.
- Never add a permanent rule from a single isolated comment.
- Never expose secrets, tokens, or private data in summaries.
- Prefer small, targeted improvements.
- Keep all proposed changes versioned in the repository.

## Output format

Respond using this structure:

## PRs analyzed

## Repeated feedback patterns

## Suggested rule updates

## Suggested skill updates

## Suggested subagent updates

## Not recommended as rules

## Confidence

## Approval needed

In **Approval needed**, ask explicitly whether to apply each proposed edit; do not write files until the user approves.

## Related project skills

- `sync-pr-comments-to-agent-improvements` — overlapping workflow with CLI-oriented fetch patterns.
- `extract-pr-feedback-learnings` — theme grouping and learning extraction without requiring GitHub MCP.

Use this skill when the user wants **GitHub MCP–driven** PR learning with the output sections above.
