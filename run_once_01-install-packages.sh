#!/usr/bin/env zsh
#
# First-run bootstrap: Homebrew, packages, language runtimes, JS toolchain.
# Ordering matters — brew must exist before `brew bundle`, and node (via nvm,
# installed by brew) must exist before corepack/bun/eas.

# 1. Xcode Command Line Tools (no-op if already present)
xcode-select --install 2>/dev/null || true

# 2. Homebrew (Apple Silicon)
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
[ -f /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"

# 3. Formulae + casks
brew bundle --file="$HOME/.config/brew/Brewfile"
brew bundle --file="$HOME/.config/brew/Caskfile"

# 4. Ruby via RVM
if [ ! -d "$HOME/.rvm" ]; then \curl -sSL https://get.rvm.io | bash -s stable; fi
source "$HOME/.rvm/scripts/rvm"
# Install only if that exact ruby is missing — never rebuild an existing one
# (rvm list strings prints `ruby-4.0.6`, hence the ruby- prefix in the match).
rvm list strings 2>/dev/null | grep -qx 'ruby-4.0.6' || rvm install 4.0.6
rvm --default use 4.0.6

# From here on the steps are idempotent and safe to re-run. Tolerate benign
# non-zero exits (e.g. corepack shims already present) so a re-run doesn't abort
# the whole script — brew bundle above stays strict so real failures still surface.

# 5. Node via mise (installed by brew in step 3)
if command -v mise >/dev/null 2>&1; then
  mise use -g node@latest
  eval "$(mise activate bash)"
fi

# 6. JS package managers via corepack (ships with node)
corepack enable || true
corepack prepare yarn@stable --activate || true    # Yarn 4.x
corepack prepare pnpm@latest --activate || true

# 7. Bun (its own installer; ~/.bun)
if ! command -v bun >/dev/null 2>&1; then curl -fsSL https://bun.sh/install | bash; fi
export BUN_INSTALL="$HOME/.bun"; export PATH="$BUN_INSTALL/bin:$PATH"

# 8. Global CLIs
bun add --global eas-cli || true    # Expo Application Services (React Native)

echo "Bootstrap complete. Restart your shell..."
exit 0
