# dotfiles

Personal macOS (Apple Silicon) dotfiles, managed with [chezmoi](https://chezmoi.io).

## Bootstrap a new machine

```sh
sh -c "$(curl -fsLS git.io/chezmoi)" -- init --apply intothefire
```

This installs chezmoi, clones this repo, prompts for machine details (email, computer name,
laptop?), and applies everything: shell config, Homebrew packages, macOS defaults, and the Dock.

## What's inside

- **Shell** — zsh with [starship](https://starship.rs) as the prompt. No oh-my-zsh; behaviour
  lives in explicit fragments under `~/.zsh_rc_files/`.
- **Packages** — `dot_config/brew/Brewfile` (formulae) + `Caskfile` (casks).
- **Provisioning** — `run_once_*` scripts: Homebrew + toolchains (Ruby, Node, Yarn 4/pnpm/bun,
  eas-cli), macOS `defaults`, and the Dock.
- **Secrets** — never committed. Live in `~/.config/.secrets` (gitignored); 1Password is the
  source of truth (shell plugins for CLIs, `op read` for env-var keys).

## Day-to-day

```sh
chezmoi diff        # preview changes before applying
chezmoi apply -v    # apply
chezmoi edit ~/.zshrc   # edit a managed file in the source dir
```

Edit files in the chezmoi source dir, not the deployed copies in `$HOME`.
See `CLAUDE.md` for architecture details.
