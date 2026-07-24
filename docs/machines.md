# Machine roles

These dotfiles serve several machine types via a **`role`** chosen at `chezmoi init`
(the "Role" prompt). It's stored in `~/.config/chezmoi/chezmoi.toml` and gates what
gets installed and configured. The shared **core** is identical on every machine.

| role | machine | gets |
|---|---|---|
| **`laptop`** | this Mac | everything — GUI apps, mobile/RN, media, Dock, full macOS defaults |
| **`mac-dev`** | headless remote Mac (SSH in) | core + AI CLIs + Ruby + mobile/RN + media + Touch ID for sudo; **no** GUI, **no** Dock |
| **`server`** | Linux AI box | core + AI CLIs + Python/uv + node (mise); **no** mac/GUI/mobile |

**Core (everywhere):** zsh + starship, fzf/fzf-tab, zoxide, eza, bat, atuin, direnv,
git + gh + delta + git-absorb, tmux + tmuxinator, mise (node), jq, gnupg, mkcert, wt,
1Password (`op`), and the AI CLIs.

## Provision a new machine
```sh
sh -c "$(curl -fsLS git.io/chezmoi)" -- init --apply intothefire
# answer Role: laptop | mac-dev | server
```
Gating lives in `dot_config/brew/Brewfile.tmpl` + `Caskfile.tmpl` and the `run_once_*`
scripts (`.role` / `.chezmoi.os`).

## Remote Mac (`mac-dev`) — the SSH + tmux workflow
1. On the Mac: `sudo systemsetup -setremotelogin on` (enable Remote Login)
2. Bootstrap it with role **`mac-dev`** — installs the CLI/dev/mobile toolchain, no GUI
3. SSH over **Tailscale**: `ssh you@<tailscale-name>`
4. `tmux new -s main` (or `mux start <proj>`) — resurrect + continuum keep it alive across
   disconnects and reboots; `tmux attach` to return
5. On the laptop, **`F12`** disables local tmux keys so your prefix drives the remote tmux

`dot_ssh/authorized_keys.tmpl` provisions your GitHub public keys, so your laptop's
1Password SSH agent can log in key-based once the box is bootstrapped.

## Linux `server` — status / TODO
The **package matrix already excludes mac-only formulae on Linux** (Brewfile.tmpl gates
on `.chezmoi.os`). What still needs wiring + validation **on an actual Linux box**:

- `run_once_01`: install Homebrew-on-Linux (or apt), add `uv` for Python, skip rvm/Ruby
- shell fragments: Linux clipboard (`wl-copy`/`xclip`) in tmux instead of `pbcopy`; skip
  the mac-only PATH/hooks (Kiro, Antigravity, JetBrains, `/opt/homebrew`)
- these are `.chezmoi.os`-gated — finish and test when the server exists

Until then, `laptop` and `mac-dev` are fully supported; `server` has the right package
set but needs the bootstrap/shell Linux pass.
