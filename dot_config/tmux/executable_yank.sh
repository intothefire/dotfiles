#!/usr/bin/env bash
#
# tmux copy backend, deployed by chezmoi to ~/.config/tmux/yank.sh.
# Resolves the best clipboard sink and, crucially for SSH sessions, falls back
# to an OSC 52 escape sequence so text copied inside a *remote* tmux lands in
# the *local* machine's clipboard. Adapted from samoshkin/tmux-config.

set -eu

is_app_installed() {
  type "$1" &>/dev/null
}

# Read the copyable text from stdin (or the file args tmux passes).
buf=$(cat "$@")

copy_backend_remote_tunnel_port=$(tmux show-option -gvq "@copy_backend_remote_tunnel_port")
copy_use_osc52_fallback=$(tmux show-option -gvq "@copy_use_osc52_fallback")

# Resolve a native clipboard backend: pbcopy (macOS), xsel/xclip (Linux/X),
# wl-copy (Wayland), or a remote tunnel port if one is configured.
copy_backend=""
if is_app_installed pbcopy; then
  copy_backend="pbcopy"
elif is_app_installed reattach-to-user-namespace; then
  copy_backend="reattach-to-user-namespace pbcopy"
elif [ -n "${WAYLAND_DISPLAY-}" ] && is_app_installed wl-copy; then
  copy_backend="wl-copy"
elif [ -n "${DISPLAY-}" ] && is_app_installed xsel; then
  copy_backend="xsel -i --clipboard"
elif [ -n "${DISPLAY-}" ] && is_app_installed xclip; then
  copy_backend="xclip -i -f -selection primary | xclip -i -selection clipboard"
elif [ -n "${copy_backend_remote_tunnel_port-}" ] \
    && (netstat -f inet -nl 2>/dev/null || netstat -4 -nl 2>/dev/null) \
      | grep -q "[.:]$copy_backend_remote_tunnel_port"; then
  copy_backend="nc localhost $copy_backend_remote_tunnel_port"
fi

# Native backend found: use it and stop.
if [ -n "$copy_backend" ]; then
  printf "%s" "$buf" | eval "$copy_backend"
  exit
fi

# No native backend (typical on a bare SSH box) — fall back to OSC 52 unless disabled.
if [ "$copy_use_osc52_fallback" == "off" ]; then
  exit
fi

buflen=$(printf %s "$buf" | wc -c)

# OSC 52 caps at ~100_000 bytes: 7 header + 1 footer + base64 of 74_994 raw bytes.
maxlen=74994
if [ "$buflen" -gt "$maxlen" ]; then
  printf "input is %d bytes too long" "$((buflen - maxlen))" >&2
fi

# Build the OSC 52 sequence, wrapped for tmux passthrough (\033Ptmux;...).
esc="\033]52;c;$(printf %s "$buf" | head -c $maxlen | base64 | tr -d '\r\n')\a"
esc="\033Ptmux;\033$esc\033\\"

# Send to the controlling terminal. Over SSH, SSH_TTY carries it to the local
# terminal emulator, which writes it into the local clipboard.
pane_active_tty=$(tmux list-panes -F "#{pane_active} #{pane_tty}" | awk '$1=="1" { print $2 }')
target_tty="${SSH_TTY:-$pane_active_tty}"

printf "$esc" > "$target_tty"
