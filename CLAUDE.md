# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

The **chezmoi source directory** for Chris's personal macOS (Apple Silicon) dotfiles.
It is not a runnable project — no build/test/lint. Files here are templates and scripts
that chezmoi renders into `$HOME`. Editing a file here changes nothing until it is applied.

Bootstrap a new machine:
`sh -c "$(curl -fsLS git.io/chezmoi)" -- init --apply intothefire`

## chezmoi naming conventions (the filename IS the deployment instruction)

- `dot_foo` → `~/.foo` (e.g. `dot_zshrc` → `~/.zshrc`, `dot_zsh_rc_files/` → `~/.zsh_rc_files/`)
- `*.tmpl` → rendered as a Go text/template before writing (drop `.tmpl` from the target name)
- `run_once_*` → runs once per machine; re-runs only if its contents change
- `run_after_change-*` → runs on every apply where its contents changed
- Numeric prefixes (`run_once_01…`, `02…`, `03…`) enforce order

## Applying and previewing

```bash
chezmoi diff              # preview what apply would change in $HOME — always do this first
chezmoi apply -v          # render + apply everything
chezmoi apply -v ~/.zshrc # apply a single target
chezmoi execute-template < file.tmpl   # test-render a template with current data
chezmoi data             # dump template data (email, name, computername, laptop)
```

Edit source files **here**, then `chezmoi diff` / `apply`. Never hand-edit deployed files
in `$HOME` — apply overwrites them.

## Shell architecture (no framework — oh-my-zsh was removed)

`dot_zshrc` is the orchestrator; the prompt is **starship**. There is no oh-my-zsh and no
powerlevel10k. Behaviour that oh-my-zsh used to provide lives in explicit fragments under
`dot_zsh_rc_files/` (→ `~/.zsh_rc_files/`), sourced by `.zshrc` in this order:

```
core  plugins  aliases  wt  path  agent-vault  (+ commands/ai)
  … Java, starship, Kiro post, bun, ~/.local/bin …
mise  moon                                     (after the last static PATH edit)
```

- `core` — history, options, keybindings, completion styling, LS_COLORS
- `plugins` — `zsh-autosuggestions` + `zsh-you-should-use` (brew); `zsh-syntax-highlighting`
  is sourced **last** directly in `.zshrc` (it must load after everything else)
- `aliases` — curated git shell aliases
- `wt` / `path` — worktrunk integration, static PATH additions (incl. `PROTO_HOME` and
  `~/.proto/shims:~/.proto/bin`)
- `mise` — global toolchain manager; `mise activate` hooks precmd + chpwd
- `moon` — puts a moon workspace's pinned toolchain ahead of mise (see below)
- `agent-vault` — credential-broker client env + `avc`/`av` wrappers (see below)

compinit runs once in `.zshrc` (brew completions fpath is set before it), so any brew formula
that ships a zsh completion (e.g. `openspec`) is picked up with no extra wiring. Tool-managed
blocks (Kiro CLI pre/post, bun, Antigravity) are kept in `.zshrc` as-is. The old
`# OPENSPEC:START/END` block was removed: it pointed fpath at the deleted oh-my-zsh tree, and
its `compinit` is now the plain, unmarked one. OpenSpec itself is installed by the Brewfile.

### Toolchains: mise global, proto per moon workspace

- **mise** is the global toolchain manager (`dot_config/mise/config.toml.tmpl`). Its pins win
  everywhere outside a moon workspace.
- **proto** is used only inside **moon** workspaces, which pin toolchains in
  `.moon/toolchains.yml`. moon is the standard monorepo tool. proto and moon live in
  `~/.proto`, installed by `run_once_05`.
- proto does **not** read `.moon/toolchains.yml`; only moon does, for the tasks it runs. So
  in a workspace, a bare `node` would get mise's version, and proto's shim fails with
  "failed to detect an applicable version". The `moon` fragment bridges this. Its
  precmd/chpwd hook finds the nearest `.moon/toolchains.yml`. For each toolchain with a
  `version:` it exports `PROTO_<ID>_VERSION` and puts `~/.proto/shims` first on PATH. For
  `rust` it also sets `RUSTUP_TOOLCHAIN` and puts `~/.cargo/bin` (the rustup proxies) first.
  mise's rustc/cargo shims force mise's own toolchain whatever `RUSTUP_TOOLCHAIN` says, so
  they must not win in a workspace. Leaving the workspace undoes all of it.

PATH precedence, highest first:

```
in a moon workspace:  ~/.cargo/bin (if rust pinned)  ~/.proto/shims
everywhere:           mise tools  ~/.local/bin  bun  ~/.proto/shims  ~/.proto/bin  brew …
```

Why the order is what it is (verified with `whence -p node rustc cargo moon`):

- **mise re-prepends its dirs** on every prompt and every `cd`. A static `PATH=` edit can
  never beat it at a prompt, so the workspace override has to be a hook registered
  **after** mise's (zsh runs hooks in registration order). That is why `moon` follows `mise`.
- **Shells that never draw a prompt** (`zsh -i -c`, agent tool shells) get only mise's
  first pass at activation. Anything prepended after that wins there. `mise` used to be
  sourced early, so `~/.local/bin` (added later in `.zshrc`) won, and `node` resolved to
  `~/.local/bin/node`. That is a symlink to Hermes's private Node 22, written by the Hermes
  agent installer, not mise's pin. So `mise` + `moon` are sourced after the last static PATH
  edit. A new PATH line in `.zshrc` goes **above** that block.
- The `moon` hook re-reads `toolchains.yml` only when the workspace root changes. After
  editing it, `cd` out and back in.

## Secrets (never committed)

Secrets live in `~/.config/.secrets` (mode 600, gitignored, **not** chezmoi-managed).
`.zshrc` sources it early. It holds `OP_SERVICE_ACCOUNT_TOKEN` (the 1Password bootstrap) plus
API keys. 1Password is the intended source of truth:

- **CLI auth** (gh, vercel, npm, cargo, brew) → each tool's own login, such as `gh auth login`.
  1Password shell plugins were removed: they failed whenever `op` lost the desktop app.
- **Env-var API keys** (Voyage, Linear, Infisical, openclaw) → `op read`, or the local file.

Never put a real secret in a tracked file.

## Agent Vault (credential broker for AI agents)

[Agent Vault](https://docs.agent-vault.dev) brokers credentials so an agent never holds a real
secret: the agent calls upstream APIs normally and the broker's transparent proxy injects the
credential in flight.

- **The server is NOT managed here.** It already runs on a separate host, reached over
  Tailscale. That separation is the security property — a broker on the same machine as the
  agent sits in a filesystem the agent can read. These dotfiles configure **clients only**;
  nothing here starts a server.
- **Broker URL is committed** in `dot_zsh_rc_files/agent-vault` (a plain fragment, not a
  template). It is not a credential — reaching it still requires tailnet membership. This was
  chosen over a chezmoi prompt so a new mac needs no manual step; the trade is that the tailnet
  name is public. Do not reintroduce an `agentvaultaddr` prompt: `.chezmoi.toml.tmpl` uses
  plain `promptString`, so touching that file makes **every** value re-prompt on `chezmoi init`.
- `run_once_04-install-agent-vault.sh.tmpl` installs the CLI on `laptop`/`mac-dev` only, via the
  upstream script (no brew formula exists). It warns rather than dies, and skips when sudo
  isn't available non-interactively so an unattended apply can't hang on a password prompt.
- **Login is interactive and per-machine**: `agent-vault auth login`. Not automatable.
- Wrap an agent with `avc` (= `agent-vault run --vault claude -- claude`) or `av <agent>`.
  `avc` defaults to the `claude` vault, skipping the run picker; `--vault <name>` (or
  `--vault=<name>`) anywhere before a literal `--` overrides it, and every other arg goes
  to claude. It is a function, not an alias. `claude` is
  deliberately **not** shadowed — `agent-vault run` aborts when the broker is unreachable, so
  aliasing it would break the agent whenever Tailscale is down. One-line flip in the fragment.
- No MITM root is installed into the system keychain. `agent-vault run` sets the CA-trust vars
  on the child process only; system-wide trust would expose every browser and app on the Mac.
- `agent-vault run` also writes `~/.claude/skills/agent-vault-cli/SKILL.md`. It is tool-managed
  and rewritten on launch — do **not** version it (same reasoning as the plugin ledgers).

The **agent-facing** rule — Claude never holds a real credential, works with placeholders,
and raises a proposal on 401/403 — lives in `dot_claude/ENGINEERING.md` (§ Secrets and
Credentials), with a one-line ban in `dot_claude/CLAUDE.md`. It is also injected into
`autoMode.environment` so auto-mode risk assessment knows it. This section stays about
*client setup*; that one is about *agent behaviour*.

`vault run` is a wrapper, **not** a sandbox: a child can unset `HTTPS_PROXY` and reach the
network directly. It removes credentials from the agent's reach; it does not contain the agent.

## Claude Code config (`~/.claude`) — a file with several writers

chezmoi owns config only: `CLAUDE.md`, `ENGINEERING.md`, `RTK.md`, `statusline.sh`, `skills/`,
`agents/`, and `settings.json`. Session state (`projects/`, `history.jsonl`, `tasks`, `plans`) belongs to
**claude-sync**; the two tools must never own the same path.

`settings.json` is deployed by `modify_private_settings.json.tmpl` — a chezmoi **`modify_`
script**, not a plain template. It receives the current file on stdin and emits the merged
result, because several things write to it: Chris, Claude Code itself (plugin toggles,
`permissions.defaultMode`, `autoMode`), and third-party installers (Bartender/NotchBar, herdr).
A plain template lost that race and clobbered them on every apply. Three zones:

- **ENFORCE** — `model`, `statusLine`, `enabledPlugins`, `extraKnownMarketplaces`, `tui`,
  `agentPushNotifEnabled`, the `rtk` PreToolUse hook, and the `permissions` allow/ask/deny
  floors. Permissions are **unioned**, so a grant made locally via `/permissions` survives;
  the listed entries are guaranteed present. The rtk hook is upserted by identity so the
  `PreToolUse` array is never replaced.
- **PRESERVE** — the default. Anything not named passes through: Bartender's hooks, herdr's
  `SessionStart` hook, `autoMode`'s generated environment block, `permissions.defaultMode`,
  and whatever a future tool injects. Bartender therefore needs **no** `{{ if .laptop }}`
  guard — it injects its own hooks wherever it is installed, so a mac mini simply never
  gets them.
- **PURGE** — hook commands matching `\.orca/agent-hooks` or `SUPERSET_HOME_DIR` are stripped
  on every apply. Orca and Superset were dropped as products; this keeps their removal
  durable if either installer ever runs again.

`autoMode.environment` is authored as readable markdown in
`docs/claude-auto-mode-environment.md` and injected by the same script: one array entry per
line, with blank lines and whole-line HTML comments stripped so the file can carry its own
header. `docs/` is `.chezmoiignore`d, so the markdown itself never lands in `$HOME`. Edit the
markdown, then `chezmoi diff ~/.claude/settings.json`. `autoMode.soft_deny` is deliberately
left in PRESERVE. Remember this key is **user-level** — it applies in every repo, so it must
never say "this repo".

Gotchas, all verified the hard way:

- `modify_` must come **before** `private_` in the filename. Reversed, chezmoi silently
  deploys a literal file named `modify_private_settings.json` and does nothing useful.
- The script falls back to emitting stdin unchanged if `jq` fails, so a broken filter can
  never truncate `settings.json`. jq's stderr is deliberately **not** swallowed — a silent
  fall-through is indistinguishable from "nothing to do" and once hid a real bug.
- Apostrophes are a recurring hazard. The jq filter lives in a single-quoted shell string, so
  one in a *comment* breaks it. And bash does **not** respect a quoted heredoc inside `$( )` —
  an apostrophe in the body still terminates the substitution. That is why the markdown is
  embedded via `b64enc` / `base64 -d` rather than a heredoc: base64 has no shell-special
  characters, so the document can contain anything.

**Tool-managed, deliberately not versioned** (same reasoning as the agent-vault `SKILL.md`):
`hooks/herdr-agent-state.sh` is written by herdr and overwritten whenever the integration
updates — the Brewfile manages the `herdr` formula, herdr manages its own hook and its
`settings.json` entry. `plugins/installed_plugins.json` and `plugins/known_marketplaces.json`
are stateful ledgers (absolute paths, timestamps, `gitCommitSha`) that Claude Code rewrites on
every plugin op; the declarative enabled-set lives in `settings.json` instead. Cost: a fresh
machine needs a manual `/plugin` install pass.

## Orchestrator and worker agents

`dot_claude/agents/` deploys `orchestrator` and `worker` to `~/.claude/agents/`. Chris starts
`avc --agent orchestrator`; it starts each worker as a full session in its own Herdr tab and
worktree. An agent's body replaces Claude Code's default system prompt, while `CLAUDE.md`
still loads, so the agent files must carry their own working instructions. The workflow rules
live in `dot_claude/ENGINEERING.md`; their auto-mode copy is in
`docs/claude-auto-mode-environment.md`, so change both together. Add specialist workers as
new files once a role needs different instructions.

Both agents may use subagents, but only the read-only `Explore` and `Plan` types. A
`PreToolUse` hook on `Agent` in each file's frontmatter enforces this as an allowlist: it
denies any other `subagent_type`, including `general-purpose`, `claude`, plugin agents, and
forks (which carry no type). Two mechanisms that look right do not work:

- `disallowedTools: Agent(x)` removes the **whole** `Agent` tool, not one type. That is why
  the agents had no `Agent` tool at all when the field read `Agent(worker), Agent(orchestrator)`.
- `tools: Agent(Explore, Plan)` is a real allowlist, but `tools` restricts the entire toolset,
  so every built-in and MCP server would have to be listed by hand.

Claude Code skips frontmatter hooks for an agent whose file is in an untrusted folder. The
deployed agents are user-scoped (`~/.claude/agents/`), so this only affects tests.

The `post-start` hook in `.config/wt.toml` opens WebStorm on each new worktree for review. It
must be committed: a new worktree contains only committed files, so a staged hook never runs.

## Homebrew

`dot_config/brew/Brewfile` (formulae + taps) and `dot_config/brew/Caskfile` (casks) are the
curated package set, applied by `run_once_01` via `brew bundle`. Prefix is `/opt/homebrew`
(Apple Silicon). Note: aliased casks (e.g. `amazon-q`↔`kiro-cli`, `linear`↔`linear-linear`)
share one app — uninstalling either token removes the app; verify the target before removing.

## Provisioning (run_once, in order)

1. `run_once_01-install-packages.sh.tmpl` — Homebrew → trust taps → `brew bundle` →
   **mise** (exact pins for Node, npm, pnpm, Yarn 4 + Ruby 4.0.6, Rust and claude-sync; no corepack) → uv → bun →
   eas. Critical steps (brew install, `brew bundle`) fail loud so chezmoi retries;
   toolchain steps warn. Role/os-gated; no RVM/nvm.
2. `run_once_02-configure-mac.sh.tmpl` — macOS `defaults`. Carries `FIX:`/`FLAG:` comments
   from a 2026 review pass; some blocks (Mail, Terminal.app) are no-ops for this setup.
3. `run_once_03-configure-dock.sh.tmpl` — rebuilds the Dock via `dockutil`. JetBrains apps
   resolve at stable `~/Applications/*.app` Toolbox paths.
4. `run_once_04-install-agent-vault.sh.tmpl` — Agent Vault CLI (see Agent Vault above).
5. `run_once_05-install-proto-moon.sh.tmpl` — proto's official installer into `~/.proto`
   (`--yes --no-modify-profile --no-modify-path`: the fragments own PATH), then
   `proto install moon <pin> --pin global` so `moon` works outside a repo. Exact pins, bump
   by hand. laptop/mac-dev only. Warns rather than dies, needs no sudo. Not the brew
   formulae: proto self-upgrades in `~/.proto`, and a brew `moon` would bypass a repo's
   proto-pinned moon version. Do not install both ways.

`run_after_change-update-tower-plist.sh` writes the current `$PATH` into Git Tower's env plist.

## Templates

`.chezmoi.toml.tmpl` prompts on init and writes `~/.config/chezmoi/chezmoi.toml`, providing
`.email`, `.name`, `.computername`, `.laptop`. Most templates guard on
`{{ if eq .chezmoi.os "darwin" }}`. `.chezmoiexternal.toml` is intentionally empty (zsh plugins
come from Homebrew now, not vendored archives).
