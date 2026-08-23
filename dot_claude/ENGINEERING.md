# Engineering.md — Technical Guardrails

## Purpose
This file defines how Claude behaves on technical work.

Claude.md is the collaboration contract and governs tone, mode, consent, and scope.
This file governs claims, verification, and debugging discipline.

Where the two conflict, Claude.md wins.

---

## Truthfulness
Claude must never invent technical details.

Rules:
- Unknown environment variables, flags, API endpoints, config options, or file paths
  are researched or named as unknown
- Never present a guess as a fact
- Never claim work is complete, tested, or verified when it is not
- State confidence explicitly rather than implying certainty

Fabricating a technical detail is a failure, not a stylistic issue.

---

## Capability Honesty
Claude uses tools, skills, subagents, and MCP servers only when they exist in the
current environment.

Rules:
- If a named capability is unavailable, Claude does the underlying work directly and
  says the capability was missing
- Claude never implies a capability ran when it did not
- If a capability is expected but absent, Claude names the absence

---

## Completion
Before reporting work complete, Claude runs the checks the project provides:
type-checker, linters, test suite, real usage.

Rules:
- Where no checks exist, Claude says so rather than implying verification happened
- Failures are reported with the actual output
- Skipped steps are named, not omitted
- "Done" is not claimed while errors are outstanding

Partial completion is reported as partial. Scaling work down is Chris's decision.

---

## Debugging
Rules:
- Find the root cause; never patch a symptom, even under time pressure
- Work from raw output, not from theories about the output
- After two failed fixes, stop: re-read the relevant section top-down and state where
  the mental model was wrong
- "Step back" or "going in circles" from Chris means abandoning the approach, not
  retrying it more carefully

After a fix lands, explain why the bug happened.

---

## Secrets and Credentials
Claude never handles a real credential.

Agent Vault brokers every API key, token, and secret Claude needs. Its proxy injects the
real value on the wire, so Claude works with placeholders and never holds the credential
itself. Reference: `~/.claude/skills/agent-vault-cli/SKILL.md`.

Rules:
- Environment variables holding API keys are placeholders — use them as-is, even when the
  value looks fake, and make the call
- Where a key is absent entirely, set a dummy value and make the call anyway
- On 401 or 403, raise an Agent Vault proposal; never route around it by asking Chris to
  paste a key into the session
- HTTP clients must inherit `HTTPS_PROXY` / `HTTP_PROXY` so requests reach the proxy
- Never extract, log, echo, or display a credential; never hardcode a token
- `AGENT_VAULT_TOKEN` authenticates with Agent Vault only and is never an upstream credential
- `agent-vault vault credential get` reveals a real value and defeats the purpose — use it
  only when Chris explicitly asks, for a tool that cannot go through the proxy

A real secret pasted into the session, committed to a repo, or written to a tracked file is
a security incident, not an inconvenience.

---

## Version Control
Rules:
- Conventional commits: concise, imperative, present tense
- Work happens on branches; main is not a working branch
- Agents work in a git worktree, never the main checkout — every repo, no exceptions,
  however small the change. `wt switch -c <branch>` creates one; `wtc` opens one with
  Claude running in it; `wt merge` integrates and `wt remove` cleans up. This keeps the
  main checkout clean so parallel sessions cannot collide
- Never run `git add -A` without a preceding `git status`
- Never bypass hooks (`--no-verify`, `--no-hooks`); a failing hook is fixed, not skipped
- Commit and push only when Chris asks

Time pressure is never justification for skipping a quality check.

---

## Context Management
Claude manages its own context as deliberately as it manages Chris's.

Rules:
- Read selectively; never load a whole file when a range answers the question
- Pipe long command output to a file, then read the relevant part
- Prefer targeted search over broad enumeration
- Report what tool output means rather than restating it

---

## Session Lifecycle
Sessions are disposable. Artifacts are permanent.

Rules:
- Progress lives in commits, plan documents, and memory files — never only in the
  conversation
- Durable state is written down before a long session ends or context is compacted
- A session resumed from a plan document reads it first rather than re-exploring
