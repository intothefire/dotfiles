<!-- Injected into ~/.claude/settings.json at `autoMode.environment` by -->
<!-- dot_claude/modify_private_settings.json.tmpl. One array entry per line. -->
<!-- Blank lines and these HTML-comment lines are stripped, so both are free -->
<!-- to use for readability. Everything else is injected VERBATIM. -->
<!-- -->
<!-- This is USER-LEVEL config: it applies in EVERY repo Chris opens, not one. -->
<!-- Never write "this repo" here — name the scope explicitly instead. -->
<!-- Edit this file, then: chezmoi diff ~/.claude/settings.json -->

### Org-wide

**Repository trust domains**: Three tiers, and the default for anything unrecognised is the strictest. (1) `intothefire/*` on github.com — Chris's personal repos (dotfiles, homelab.norman.me, finance/health/healthsave.norman.me, tasuki, portfolio): non-secret confidential material may be committed. (2) `convergent-app/*` — owned by Chris, but treat it as a commercial organisation and apply a higher level of care than `intothefire/*`: assume commercial confidentiality, keep personal notes and cross-repo context out, and do not copy its contents into personal repos or public services. (3) Everything outside `intothefire/*` is an external organisation — including `facebook/*` (reached with the org-scoped SSH identity `org-69631@github.com`) and the third-party upstream clones under `~/Projects/scratch/` (`Fission-AI/OpenSpec`, `github/spec-kit`, `garrytan/*`, `umutkeltek/*`). Treat external repos as the property of their owner: no personal or cross-repo material in, nothing copied out, and no pushing to their origins unless Chris says otherwise.

**Repository visibility**: Personal `intothefire/*` repos are private. Do not assume visibility for any other repo — confirm with `gh` before treating one as private.

**Worktrees**: Agents make changes in a git worktree, never directly in the main checkout — in every repo, homelab.norman.me included, and even for a one-line change. Create or switch with `wt switch -c <branch>` (worktrunk); the `wtc` alias opens a new worktree with Claude already running in it. Worktrees are centralised at `~/worktrees/<repo-path>/<branch>`. Integrate with `wt merge`, clean up with `wt remove`. This keeps the main checkout clean so parallel agent sessions cannot collide with each other or with Chris.

**Default / protected branches**: Default branch is `main` across Chris's repos, and `main` is not a working branch — work happens on branches. Do not infer a repo is unprotected merely because `gh` lists no rulesets; rulesets are not always queryable.

**Secrets management**: 1Password is the source of truth on Chris's machines — CLI auth via shell plugins, env-var API keys via `op read`. Self-hosted Infisical (project `homelab`, env `prd`) is the runtime secret store for the homelab fleet, injected by Komodo's `infisical-run.sh` wrapper. Machine-local secrets live in `~/.config/.secrets` (mode 600, gitignored, deliberately not chezmoi-managed). Agent Vault brokers credentials over the tailnet so an agent never holds a real secret. Real secrets are never committed in any repo; only `*.example` counterparts are tracked.

**Credential handling**: Claude never holds a real credential. Agent Vault brokers them: its proxy matches each outbound request against configured services and injects the real API key, token, or secret on the wire, so any credential-shaped environment variable Claude can see is a placeholder. Use placeholders as-is even when they look fake and make the call; where none exists, set a dummy value and call anyway. On 401 or 403, raise an Agent Vault proposal rather than asking Chris to paste a key into the session. HTTP clients must inherit `HTTPS_PROXY` / `HTTP_PROXY`. Never extract, log, display, or hardcode a credential. `AGENT_VAULT_TOKEN` authenticates with Agent Vault only and is never an upstream credential. `agent-vault vault credential get` reveals a real value and defeats the purpose — use it only when Chris explicitly asks, for a tool that cannot proxy. Reference: `~/.claude/skills/agent-vault-cli/SKILL.md`.

**Agent Vault boundary**: The broker runs on a separate Tailscale host, deliberately not on the machine running the agent — a broker sharing a filesystem with the agent is one the agent can read. `agent-vault run` is a wrapper, not a sandbox: it removes credentials from the agent's reach but does not contain the agent, and a child process can unset the proxy variables and reach the network directly. No MITM root is installed system-wide; CA trust is set on the child process only.

**Internal sharing / snippet hosting**: None configured — treat public paste and gist services as outside the trust boundary in every repo.

**Network posture**: Tailscale tailnet `tail8749b.ts.net` is the primary internal network; Cloudflare Tunnel fronts selected public exposure; Authentik gates access via SSO. Reaching any internal host requires tailnet membership — there is no public ingress tier.

**Trusted internal domains**: `*.tail8749b.ts.net` — the personal tailnet (infisical, komodo, agent-vault, forgejo, glance, plex-mcp, dawarich, healthsave, and other self-hosted services).

**Key internal services**: Infisical (secrets), Komodo (GitOps deploy and build), Authentik (SSO/OIDC), Forgejo (git and container registry), AdGuard Home with Unbound (DNS), Tailscale (mesh networking), Agent Vault (credential broker for agents).

**CI/CD deploy targets**: Komodo (GitOps) deploys Docker Compose stacks to the homelab fleet (lunkwill, deep-thought, marvin, fook) via Periphery agents, and builds images into the self-hosted Forgejo registry. Only homelab.norman.me deploys; no other repo has a deploy target configured.

**Internal package registry**: Self-hosted Forgejo registry.

**Cloud provider(s) and buckets**: None configured. Backups run through Backrest to Dropbox/Drive; Backblaze B2 appears historically but is not in current use.

**Sensitive remote targets**: Any host, namespace, container, or environment carrying `prod` or `production` as a whole word or segment. Also production-equivalent regardless of naming: Infisical env `prd`, and the live homelab hosts lunkwill, fook, marvin, deep-thought, magrathea, and benjy — this is a live fleet serving real use, not a staging environment. benjy is a disk-constrained Raspberry Pi where surplus files have already caused an outage.

**Protected IaC scopes**: IAM, RBAC, networking, quota, and node-pool resources in any repo, plus anything whose name or tag carries `prod`/`production`. In homelab.norman.me specifically: `ansible/roles/network` (fook's static-NIC configuration, flagged high-blast-radius) and `group_vars/all.yml` (the bootstrap secrets root).

**Sensitive data locations & audiences**: Gitignored secret material — `group_vars/all.yml`, `.env`, `doppler.env`, `secret.yaml`, `*.token`, `~/.config/.secrets`, and `~/.claude-sync/age-key.txt`. Only `*.example` counterparts are tracked. Audience is Chris and his own infrastructure.

**Data retention / declassification**: None configured.

### User-specific

**Primary use of Claude Code**: A mix — self-hosted infrastructure-as-code (Ansible, Docker Compose, Komodo GitOps), personal web and data applications under `norman.me`, dotfiles and developer tooling, and occasional work in organisation repos. The repo in the working directory defines the task; assumptions do not carry from one repo into another.

**Working style**: Chris proposes, Claude critiques; Claude drafts, Chris approves. Plan before executing anything multi-file, structural, or irreversible; execute single-file reversible changes directly and report what changed. Partial completion is reported as partial — scaling work down is Chris's call. Never bypass a failing hook or quality gate.

**Org-specific CLIs**: `chezmoi` (dotfiles), `op` (1Password), `infisical` (secrets), `ansible-playbook` (provisioning), Komodo tooling, `tailscale`, `agent-vault` / `avc` (credential broker), `rtk` (token-optimised CLI proxy), `wt` (worktrunk worktrees), `mise` (runtime versions), `gh`, `claude-sync` (agent session state), `herdr` (agent multiplexer).

**Routine working scope**: Editing source, tests, documentation, and configuration within the current repo is normal and expected. Escalate before touching a second repo, pushing to any origin, deploying, or acting on a production-equivalent target named above.
