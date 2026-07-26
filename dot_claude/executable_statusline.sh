#!/usr/bin/env bash
#
# Statusline script for Claude Code - The Agentic Startup
#
# Features:
# - Spec ID and name (if in spec worktree)
# - Git branch with type awareness
# - TodoWrite progress (if active)
# - Linear issue ID (if synced)
# - Model name (short form)
#
# Input: JSON from Claude Code via stdin
# Output: Single formatted statusline with ANSI colors
#
# Performance target: <50ms execution time
#

# ANSI color codes
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

# Vibrant branch type colors
COLOR_DOCS="\033[1;38;2;65;165;255m"    # Bright blue (bold)
COLOR_FEAT="\033[1;38;2;0;230;118m"     # Bright green (bold)
COLOR_FIX="\033[1;38;2;255;82;82m"      # Bright red (bold)
COLOR_REFACTOR="\033[1;38;2;255;170;0m" # Bright orange (bold)
COLOR_PERF="\033[1;38;2;0;230;230m"     # Cyan (bold)
COLOR_TEST="\033[1;38;2;186;85;255m"    # Purple (bold)
COLOR_CHORE="\033[38;2;160;160;160m"    # Gray
COLOR_DEFAULT="\033[38;2;220;220;220m"  # Light gray
COLOR_MAIN="\033[1;38;2;255;255;255m"   # White (bold) for main branch

# Accent colors - vibrant
COLOR_SPEC="\033[1;38;2;255;200;0m"     # Bright gold (bold) for spec ID
COLOR_TASKS="\033[1;38;2;200;100;255m"  # Bright purple (bold) for tasks
COLOR_LINEAR="\033[1;38;2;92;170;255m"  # Linear blue (bold)
COLOR_MODEL="\033[38;2;130;130;130m"    # Muted for model

# Icons with color
ICON_SPEC="\033[1;38;2;255;200;0m⬡\033[0m"     # Gold hexagon
ICON_BRANCH="\033[38;2;180;180;180m⎇\033[0m"   # Branch symbol
ICON_TASKS="\033[1;38;2;200;100;255m◈\033[0m"  # Purple diamond
ICON_LINEAR="\033[1;38;2;92;170;255m◉\033[0m"  # Linear circle

# Separator - subtle
SEP="${DIM} · ${RESET}"

# Read JSON from stdin
IFS= read -r -d '' json_input || true

# Extract current_dir
current_dir=""
if [[ "$json_input" =~ \"workspace\"[^}]*\"current_dir\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
  current_dir="${BASH_REMATCH[1]}"
fi
if [[ -z "$current_dir" && "$json_input" =~ \"cwd\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
  current_dir="${BASH_REMATCH[1]}"
fi
[[ -z "$current_dir" ]] && current_dir="$PWD"

# Extract model display_name and shorten it
model_name=""
if [[ "$json_input" =~ \"model\"[^}]*\"display_name\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
  model_name="${BASH_REMATCH[1]}"
fi
# Shorten model names
case "$model_name" in
  *"Opus"*) model_name="Opus" ;;
  *"Sonnet"*) model_name="Sonnet" ;;
  *"Haiku"*) model_name="Haiku" ;;
  "") model_name="Claude" ;;
esac

# Get git branch
get_git_branch() {
  local dir="$1"
  [[ "$dir" =~ ^~ ]] && dir="${dir/#\~/$HOME}"

  # Check for worktree (.git is a file)
  local git_path="${dir}/.git"
  if [[ -f "$git_path" ]]; then
    # It's a worktree - read the gitdir path
    local gitdir
    gitdir=$(grep "gitdir:" "$git_path" 2>/dev/null | cut -d' ' -f2)
    if [[ -n "$gitdir" && -f "${gitdir}/HEAD" ]]; then
      local head_content
      head_content=$(<"${gitdir}/HEAD")
      if [[ "$head_content" =~ ^ref:[[:space:]]*refs/heads/(.+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
      fi
    fi
  fi

  # Regular repo (.git is a directory)
  local git_head="${dir}/.git/HEAD"
  if [[ -f "$git_head" && -r "$git_head" ]]; then
    local head_content
    head_content=$(<"$git_head")
    if [[ "$head_content" =~ ^ref:[[:space:]]*refs/heads/(.+)$ ]]; then
      echo "${BASH_REMATCH[1]}"
      return 0
    fi
    echo "HEAD"
    return 0
  fi

  echo ""
}

git_branch=$(get_git_branch "$current_dir")

# Determine branch type and color
branch_color="$COLOR_DEFAULT"
branch_type=""
if [[ "$git_branch" == "main" || "$git_branch" == "master" ]]; then
  branch_color="$COLOR_MAIN"
  branch_type="main"
elif [[ "$git_branch" =~ ^docs/ ]]; then
  branch_color="$COLOR_DOCS"
  branch_type="docs"
elif [[ "$git_branch" =~ ^feat/ ]]; then
  branch_color="$COLOR_FEAT"
  branch_type="feat"
elif [[ "$git_branch" =~ ^fix/ ]]; then
  branch_color="$COLOR_FIX"
  branch_type="fix"
elif [[ "$git_branch" =~ ^refactor/ ]]; then
  branch_color="$COLOR_REFACTOR"
  branch_type="refactor"
elif [[ "$git_branch" =~ ^perf/ ]]; then
  branch_color="$COLOR_PERF"
  branch_type="perf"
elif [[ "$git_branch" =~ ^test/ ]]; then
  branch_color="$COLOR_TEST"
  branch_type="test"
elif [[ "$git_branch" =~ ^chore/ ]]; then
  branch_color="$COLOR_CHORE"
  branch_type="chore"
fi

# Extract spec ID from branch name (e.g., docs/001-user-auth -> 001)
spec_id=""
spec_name=""
if [[ "$git_branch" =~ ^[^/]+/([0-9]{3})-(.+)$ ]]; then
  spec_id="${BASH_REMATCH[1]}"
  spec_name="${BASH_REMATCH[2]}"
fi

# Check for TodoWrite progress in the JSON
# Look for todos array and count statuses
tasks_total=0
tasks_done=0
if [[ "$json_input" =~ \"todos\" ]]; then
  # Count completed tasks
  tasks_done=$(echo "$json_input" | grep -o '"status"[[:space:]]*:[[:space:]]*"completed"' | wc -l | tr -d ' ')
  # Count all tasks (any status)
  tasks_total=$(echo "$json_input" | grep -o '"status"[[:space:]]*:' | wc -l | tr -d ' ')
fi

# Check for Linear mapping
linear_id=""
if [[ -n "$spec_id" ]]; then
  # Look for Linear mapping file
  mapping_file=$(find "${current_dir}/.the-startup-cjn/linear/mappings" -name "${spec_id}-*.json" 2>/dev/null | head -1)
  if [[ -f "$mapping_file" ]]; then
    # Extract issue ID from mapping
    if [[ $(cat "$mapping_file" 2>/dev/null) =~ \"issue_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      linear_id="${BASH_REMATCH[1]}"
    fi
  fi
fi

# Build statusline parts
parts=()

# Part 1: Spec ID and name (if in spec context)
if [[ -n "$spec_id" ]]; then
  parts+=("${ICON_SPEC} ${COLOR_SPEC}${spec_id}${RESET} ${COLOR_DEFAULT}${spec_name}${RESET}")
fi

# Part 2: Branch (with color based on type)
if [[ -n "$git_branch" ]]; then
  parts+=("${branch_color}⎇ ${git_branch}${RESET}")
fi

# Part 3: Tasks progress (if any)
if [[ "$tasks_total" -gt 0 ]]; then
  parts+=("${ICON_TASKS} ${COLOR_TASKS}${tasks_done}/${tasks_total}${RESET}")
fi

# Part 4: Linear issue (if synced)
if [[ -n "$linear_id" ]]; then
  parts+=("${ICON_LINEAR} ${COLOR_LINEAR}${linear_id}${RESET}")
fi

# Part 5: Model (always last, muted)
parts+=("${COLOR_MODEL}${model_name}${RESET}")

# Join parts with separator
statusline=""
for i in "${!parts[@]}"; do
  if [[ $i -gt 0 ]]; then
    statusline+="$SEP"
  fi
  statusline+="${parts[$i]}"
done

# Output
echo -e "$statusline"

exit 0
