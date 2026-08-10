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
core  plugins  aliases  mise  wt  path  agent-vault       (+ commands/ai)
```

- `core` — history, options, keybindings, completion styling, LS_COLORS
- `plugins` — `zsh-autosuggestions` + `zsh-you-should-use` (brew); `zsh-syntax-highlighting`
  is sourced **last** directly in `.zshrc` (it must load after everything else)
- `aliases` — curated git shell aliases
- `mise` / `wt` / `path` — runtime version manager, worktrunk integration, PATH additions
- `agent-vault` — credential-broker client env + `avc`/`av` wrappers (see below)

compinit runs once in `.zshrc` (brew completions fpath is set before it). Tool-managed blocks
(OpenSpec, Kiro CLI pre/post, bun, Antigravity) are kept in `.zshrc` as-is.

## Secrets (never committed)

Secrets live in `~/.config/.secrets` (mode 600, gitignored, **not** chezmoi-managed).
`.zshrc` sources it early. It holds `OP_SERVICE_ACCOUNT_TOKEN` (the 1Password bootstrap) plus
API keys. 1Password is the intended source of truth:

- **CLI auth** (gh, vercel, npm, cargo, brew) → 1Password **shell plugins**. `.zshrc` sources
  `~/.config/op/plugins.sh`; configure per-CLI with `op plugin init <tool>` (interactive).
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
- Wrap an agent with `avc` (= `agent-vault run -- claude`) or `av <agent>`. `claude` is
  deliberately **not** shadowed — `agent-vault run` aborts when the broker is unreachable, so
  aliasing it would break the agent whenever Tailscale is down. One-line flip in the fragment.
- No MITM root is installed into the system keychain. `agent-vault run` sets the CA-trust vars
  on the child process only; system-wide trust would expose every browser and app on the Mac.
- `agent-vault run` also writes `~/.claude/skills/agent-vault-cli/SKILL.md`. It is tool-managed
  and rewritten on launch — do **not** version it (same reasoning as the plugin ledgers).

`vault run` is a wrapper, **not** a sandbox: a child can unset `HTTPS_PROXY` and reach the
network directly. It removes credentials from the agent's reach; it does not contain the agent.

## Homebrew

`dot_config/brew/Brewfile` (formulae + taps) and `dot_config/brew/Caskfile` (casks) are the
curated package set, applied by `run_once_01` via `brew bundle`. Prefix is `/opt/homebrew`
(Apple Silicon). Note: aliased casks (e.g. `amazon-q`↔`kiro-cli`, `linear`↔`linear-linear`)
share one app — uninstalling either token removes the app; verify the target before removing.

## Provisioning (run_once, in order)

1. `run_once_01-install-packages.sh.tmpl` — Homebrew → trust taps → `brew bundle` →
   **mise** (Node + Ruby 4.0.6, via its config) → corepack (Yarn 4 + pnpm) → uv → bun →
   eas. Critical steps (brew install, `brew bundle`) fail loud so chezmoi retries;
   toolchain steps warn. Role/os-gated; no RVM/nvm.
2. `run_once_02-configure-mac.sh.tmpl` — macOS `defaults`. Carries `FIX:`/`FLAG:` comments
   from a 2026 review pass; some blocks (Mail, Terminal.app) are no-ops for this setup.
3. `run_once_03-configure-dock.sh.tmpl` — rebuilds the Dock via `dockutil`. JetBrains apps
   resolve at stable `~/Applications/*.app` Toolbox paths.

`run_after_change-update-tower-plist.sh` writes the current `$PATH` into Git Tower's env plist.

## Templates

`.chezmoi.toml.tmpl` prompts on init and writes `~/.config/chezmoi/chezmoi.toml`, providing
`.email`, `.name`, `.computername`, `.laptop`. Most templates guard on
`{{ if eq .chezmoi.os "darwin" }}`. `.chezmoiexternal.toml` is intentionally empty (zsh plugins
come from Homebrew now, not vendored archives).
