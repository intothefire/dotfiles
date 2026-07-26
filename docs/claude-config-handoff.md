# Handoff — bring `~/.claude` under chezmoi

Written 2026-07-26 as a handoff from a design session in `homelab.norman.me`. Read this
before touching anything; it carries decisions already made, not suggestions to revisit.

## Why

Chris works across two Macs: **Arthur** (the laptop, `laptop` role) and **deep-thought**
(the always-on M1 mini, `mac-dev` role). Some work runs predominantly on the mini, some is
laptop-only, some moves between them via worktrees/branches/PRs.

Right now `~/.claude` is **entirely unmanaged** — `chezmoi managed | grep claude` returns
nothing. A 14.4K `settings.json` (hooks, permissions, env), the global `CLAUDE.md`, `RTK.md`
and the installed skill/plugin set exist by hand, on one machine.

The failure mode this fixes is not aesthetic. If the mini's config differs from the laptop's,
it *behaves* differently in ways that are invisible until an agent does the wrong thing: a
missing hook, or a missing permission entry that turns an unattended run into a prompt that
blocks forever.

## The hard boundary — chezmoi owns config, nothing else

A companion tool, [`claude-sync`](https://github.com/tawanorg/claude-sync), will sync
**session state** between the two Macs (age-encrypted, over WebDAV to a self-hosted `dufs`
instance in the homelab). It is being set up separately.

**Both tools must never own the same path.** claude-sync's *full* scope also syncs
settings/skills/plugins; if that overlaps chezmoi, `chezmoi apply` and a claude-sync pull
will silently revert each other. The split:

| Owner | Paths |
|---|---|
| **chezmoi** (this repo) | `CLAUDE.md`, `RTK.md`, `settings.json`, `skills/`, the plugin *manifests* |
| **claude-sync** (`--scope sessions`) | `projects/`, `plans/`, `tasks/`, `history.jsonl` |
| **neither — pure local junk** | `cache/`, `backups/`, `chrome/`, `daemon/`, `debug/`, `downloads/`, `file-history/`, `ide/`, `jobs/`, `paste-cache/`, `security/`, `session-env/`, `shell-snapshots/`, `telemetry/`, `daemon.log`, `*.bak`, `gh-pr-status-cache.json`, `.last-*`, `security_warnings_state_*.json` |

Confirmed against claude-sync's docs: the `sessions` scope covers exactly `projects/`,
`history.jsonl`, `tasks/`, `plans/` — so with that scope selected there is **zero overlap** with
chezmoi's column. The `full` scope would collide and must not be used.

(`history.jsonl` is Claude Code's *prompt* history, not shell history — atuin does not cover it.
claude-sync syncs it last-writer-wins, so entries will be lost when both Macs are active. Known
and accepted; it is not chezmoi's problem either way.)

Within `plugins/`, `installed_plugins.json` and `known_marketplaces.json` are declarative and
worth versioning; `cache/`, `data/` and `marketplaces/` are fetched artifacts — exclude them.

## ⚠️ `~/.claude-sync/` — leave it completely alone

Separate directory, adjacent name, easy to sweep up by accident. **chezmoi must not manage any
of it**, and none of it may reach git:

- `age-key.txt` — the **derived private key, in plaintext**. The passphrase itself is never
  stored on disk; this file is the real secret at rest, and it is what makes unattended sync
  possible after a one-time interactive `claude-sync init`.
- `config.yaml` — storage config, including the dufs WebDAV credentials and the sync scope.

Both are per-machine and are created by `claude-sync init`. Add `.claude-sync` to
`.chezmoiignore` so a future glob cannot pick it up.

## ⚠️ Do NOT use `exact_dot_claude`

Source dir must be `dot_claude/`, never `exact_dot_claude/`. The `exact_` prefix makes chezmoi
**delete every unmanaged file in the target directory** — which here means all sessions, all
auto-memory, and the entire installed plugin tree. Plain `dot_claude/` touches only what is
present in the source state, which is exactly the required behaviour.

## Role scoping

`~/.claude` should apply to `laptop` and `mac-dev` only. Add `.claude` to the `.chezmoiignore`
blocks for `server` and `minimal` — lunkwill/fook/the Pis have no use for agent config, and
benjy is a Pi 3 with ~1.3GB free where a full disk has already caused a house-wide DNS outage.

## Secrets

`settings.json` has not yet been audited for tokens. Check before committing. Anything secret
goes through `op` templating — the same pattern the homelab repo already uses in
`vault-pass.sh` (`op read op://...`). 1Password CLI is installed on every box by
`run_once_01`. Nothing secret lands in git in plaintext, even though this repo is private.

Also check for machine-divergent absolute paths in hook commands (Homebrew prefix, binary
locations). Those need templating or they will resolve on one Mac and not the other.

## Coordination with the homelab repo

The Ansible side lives in `homelab.norman.me`: `ansible/roles/devbox`, `ansible/devbox.yml`,
`group_vars/devbox/`, vars prefixed `devbox_*`.

Two constraints from there:

1. **`devbox_prompt_role` must match `.chezmoi.toml.tmpl` verbatim** — currently
   `Role (laptop | mac-dev | server | minimal)`. chezmoi matches `--promptString` keys
   literally. A stale value does *not* error: it silently falls back to prompting, which
   **hangs a TTY-less run forever, on every host**. Any change to that prompt string is a
   coordinated two-repo change.
2. **Do not add a Homebrew step to Ansible.** Packages stay in `run_once_01` — Chris's
   explicit call. Ansible's remit is deliberately narrow.

## Open decision — do not settle this alone

**Arthur is not in the Ansible inventory.** Only deep-thought is in `[macdev]`. The laptop's
chezmoi is hand-driven, the mini's is Ansible-driven — two paths to the same dotfiles. Whether
Arthur joins the inventory (as `[macdev]`, or a new laptop group) is Chris's call. This work
does not depend on it; the `laptop` role already exists and `chezmoi apply` works by hand.

## Verification

Bar for done: `chezmoi apply` on Arthur is a **no-op diff** against the current live
`~/.claude` config files. Confirm with `chezmoi diff` before any apply, and confirm
`chezmoi managed | grep claude` lists only the config paths above — no `projects/`, no
`sessions/`, no `cache/`.

Then a fresh `chezmoi apply` on deep-thought should converge it to match, without disturbing
its existing session state.
