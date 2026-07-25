# tmux cheat-sheet

Quick reference for this setup (config: [`dot_tmux.conf`](../dot_tmux.conf)).

**The prefix is `Ctrl-a`.** Almost every command is: press `Ctrl-a`, let go, then press
the next key. Written below as `prefix <key>`. The gruvbox bar along the top is how you
know you're inside tmux. (Need a literal `Ctrl-a`, e.g. jump-to-line-start in the shell?
Press it **twice**.)

> ⚠️ **Leaving vs. quitting.** To step away and keep everything running in the background,
> **detach** with `prefix d` — *don't* type `exit`. `exit` (or `Ctrl-D`) closes a pane;
> closing the last pane is what quits tmux. This is the #1 thing that trips people up.

---

## Sessions — your persistent workspaces

| Command / keys | Action |
|---|---|
| `tmux` | start a new session |
| `tmux new -s work` | start a **named** session |
| `prefix d` | **detach** — leave it running in the background |
| `tmux attach` · `tmux a` | reattach to the last session |
| `tmux a -t work` | reattach to a named session |
| `tmux ls` | list sessions |
| `prefix s` | switch between sessions (interactive) |
| `prefix R` | rename the current session |
| `prefix D` | detach **other** clients (keep yourself attached) |
| `tmux kill-session -t work` | kill one session |
| `tmux kill-server` | kill everything |

A detached session survives closing your terminal — and, thanks to the continuum plugin,
even a **reboot**. Just `tmux attach` to get it all back.

## Windows — like tabs

| Keys | Action |
|---|---|
| `prefix c` | new window (opens in the current dir) |
| `prefix 1` … `prefix 9` | jump to window N |
| `prefix n` · `prefix p` | next / previous window (hold to repeat) |
| `prefix Tab` | jump to the **last** window (toggle back and forth) |
| `prefix ,` | rename window |
| `prefix w` | pick a window from a list |
| `prefix &` | close window |

## Panes — splits (custom binds)

| Keys | Action |
|---|---|
| `prefix \|` | split **left/right** |
| `prefix -` | split **top/bottom** |
| `prefix h` `j` `k` `l` | move between panes (vim-style) |
| *click a pane* | select it (mouse is on) |
| *drag a border* | resize (mouse) |
| `prefix z` · `prefix +` | **zoom** a pane to fullscreen (toggle) |
| `prefix C-o` | rotate/swap panes around |
| `prefix Space` | cycle through layouts |
| `prefix x` | close pane |

## Scroll & copy (vi keys)

| Keys | Action |
|---|---|
| `prefix [` | enter copy/scroll mode (or just scroll with the mouse) |
| `h j k l` / arrows | move around |
| `v` | start selection · `C-v` toggle rectangle (block) select |
| `y` or `Enter` | copy selection → clipboard, exit copy mode |
| `Y` | copy the whole **line** → clipboard |
| `D` | copy from cursor to **end of line** → clipboard |
| `q` | quit copy mode |

Copy runs through `~/.config/tmux/yank.sh`, which finds the right clipboard —
and over SSH falls back to an **OSC 52** escape sequence, so text you copy inside a
**remote** tmux lands in your **laptop's** clipboard. Paste anywhere with ⌘V.

## Power moves

| Keys | Action |
|---|---|
| `F12` | toggle local keys **OFF** (status greys, shows `OFF`) so an inner / **SSH'd remote** tmux receives your keys — `F12` again to restore |
| `prefix Q` | kill session (asks to confirm) |
| `prefix X` | kill window (asks to confirm) |
| `prefix b` | list copy buffers · `prefix p` paste the latest |

The session name in the status bar turns **orange** whenever the prefix is active.

## Nested / remote sessions

When tmux runs on **both** your laptop and a box you've SSH'd into, both grab `Ctrl-a`.
The remote tmux automatically draws its bar at the **bottom, in blue** (local stays orange
on top) so you can always tell them apart. To drive the remote one:

1. Press `F12` on the laptop → the **top** bar greys out and shows `OFF`.
2. Your `Ctrl-a` now passes through to the **remote** tmux (the blue bar).
3. Press `F12` again to take the laptop back.

You never press `F12` on the remote — it's a local toggle for "get out of the way."

## Config

| Keys | Action |
|---|---|
| `prefix r` | reload `~/.tmux.conf` |
| `prefix C-e` | open `~/.tmux.conf` in `$EDITOR`, then reload on save |

## Session persistence (resurrect + continuum)

| Keys | Action |
|---|---|
| `prefix Ctrl-s` | save all sessions now |
| `prefix Ctrl-r` | restore the last save |

Continuum auto-saves every 15 minutes and **auto-restores your last session** whenever the
tmux server starts (e.g. after a reboot). Pane contents and nvim sessions are captured too.

---

## Session templates with tmuxinator

Define reusable layouts in YAML at `~/.config/tmuxinator/<name>.yml`, then launch them.
`mux` is an alias for `tmuxinator`.

```sh
mux list            # your projects
mux new work        # create one (opens $EDITOR)
mux start work      # start it (or attach if already running)
mux edit work       # edit its config
mux stop work       # kill the session
```

A starter for this repo ships already — `mux start dotfiles`
(`~/.config/tmuxinator/dotfiles.yml`). A richer example:

```yaml
# ~/.config/tmuxinator/api.yml
name: api
root: ~/code/api
startup_window: edit
windows:
  - edit: nvim .
  - run:
      layout: even-horizontal
      panes:
        - npm run dev
        - npm test -- --watch
  - git:
```

Each list item is a window; `panes:` splits it (with an optional `layout:`); a string
value auto-runs that command. `mux debug <name>` prints the tmux commands it would run.

## 30-second first drive

1. `tmux new -s test` — the bar appears at the top
2. `prefix |` then `prefix -` — now you have 3 panes; click between them
3. `prefix d` — back to your normal shell, but it's **still running**
4. `tmux attach` — everything's exactly where you left it
5. Done for real? `tmux kill-session -t test`
