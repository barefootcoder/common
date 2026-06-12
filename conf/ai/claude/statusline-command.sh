#!/bin/bash

# Status line script for Claude Code
# Set to 1 to enable debug logging to /tmp/claude-statusline-debug.json
DEBUG=0

input=$(cat)

# Debug: Log JSON structure to file for debugging (only if DEBUG=1)
if [ "$DEBUG" = "1" ]; then
    echo "$input" > /tmp/claude-statusline-debug.json
fi

# Extract data from actual JSON structure
model_id=$(echo "$input" | jq -r '.model.id // "unknown"')
model_display=$(echo "$input" | jq -r '.model.display_name // "Claude AI"')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // ""')
context_window_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
session_name=$(echo "$input" | jq -r '.session_name // ""')
session_id=$(echo "$input" | jq -r '.session_id // ""')

# Session display: alias if set via /rename or --name, else first 8 chars of UUID
if [ -n "$session_name" ]; then
    session_display="$session_name"
elif [ -n "$session_id" ]; then
    session_display="${session_id:0:8}"
else
    session_display="?"
fi

# Check if sandbox mode is enabled (from settings.local.json)
sandbox_enabled="false"
settings_file="$current_dir/.claude/settings.local.json"
if [ -f "$settings_file" ]; then
    sandbox_enabled=$(jq -r '.sandbox.enabled // "false"' "$settings_file" 2>/dev/null)
fi

# Get project name from current directory
if [ -n "$current_dir" ]; then
    project_name=$(basename "$current_dir")
else
    project_name=$(basename "$(pwd)")
fi

# Cost: Claude Code now hands us the running session total directly via
# .cost.total_cost_usd, so there is no need to re-parse the whole transcript and
# price each model's tokens by hand (the old approach spawned a jq + bc per
# transcript line, and silently zeroed out whenever the transcript was missing).
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

# Format cost: 4 decimals once we are past a cent, 6 below that so tiny costs
# stay visible rather than rounding away; a flat $0.00 for a genuinely zero cost.
cost_display=$(awk -v c="$total_cost" 'BEGIN {
    if (c == 0)        printf "$0.00";
    else if (c >= 0.01) printf "$%.4f", c;
    else                printf "$%.6f", c;
}')

# Context window headroom: the raw token count is always large and hard to
# reason about, so the thing that actually matters mid-task -- how much room is
# left before space runs out -- gets lost.  Turn it around and show free space
# instead.  .total_input_tokens already folds in cache creation/reads, and
# dividing by the window size gives the same input-only basis as
# .used_percentage, so this is effectively the "NN.N% free" figure /context
# reports, minus all the per-server breakdown noise.
context_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
if [ "$context_window_size" -gt 0 ]; then
    context_free=$(awk -v t="$context_tokens" -v w="$context_window_size" \
        'BEGIN { f = (1 - t / w) * 100; if (f < 0) f = 0; printf "%.1f", f }')
else
    context_free="100.0"
fi

# Color-code free space so it stays quiet while there is plenty of room and
# escalates as headroom shrinks: green above 40%, yellow down to 25%, red down
# to 10%, then white-on-red below that to make a nearly-full window impossible
# to miss.  (The yellow/red cutoffs are the free-space complement of the old
# 60%/75%-used warning levels, plus a new critical tier.)
free_int=${context_free%.*}
if   [ "$free_int" -le 10 ]; then free_color="\e[1;97;41m"   # white on red: critical
elif [ "$free_int" -le 25 ]; then free_color="\e[1;31m"      # red
elif [ "$free_int" -le 40 ]; then free_color="\e[1;33m"      # yellow
else                              free_color="\e[32m"        # green: healthy
fi
free_display="${free_color}${context_free}% free\e[0m"

# Set cost warning and model display based on actual model ID
case "$model_id" in
    *"opus-4"*|*"opusplan"*|*"claude-4-opus"*)
        cost_warning="\e[1;31mEXPENSIVE\e[0m"
        # Derive the minor version (e.g. 4-8 -> 4.8) from the model id when present
        if [[ "$model_id" =~ opus-4-([0-9]+) ]]; then
            model_short="Opus 4.${BASH_REMATCH[1]}"
        else
            model_short="Opus 4"
        fi
        # Mark the 1M context window variant
        [ "$context_window_size" = "1000000" ] && model_short="$model_short (1M)"
        ;;
    *"sonnet-4"*|*"claude-sonnet-4"*)
        cost_warning="\e[1;36mMEDIUM\e[0m"
        if [[ "$model_id" =~ sonnet-4-([0-9]+) ]]; then
            model_short="Sonnet 4.${BASH_REMATCH[1]}"
        else
            model_short="Sonnet 4"
        fi
        [ "$context_window_size" = "1000000" ] && model_short="$model_short (1M)"
        ;;
    *"sonnet"*|*"claude-3-5-sonnet"*)
        cost_warning="\e[1;31mMODERATE\e[0m"
        model_short="Sonnet 3.5"
        ;;
    *"haiku"*)
        cost_warning="\e[1;32mCHEAP\e[0m"
        model_short="Haiku"
        ;;
    *)
        cost_warning="\e[1;31mUNKNOWN\e[0m"
        model_short="$model_display"
        ;;
esac

# Add sandbox indicator if enabled
sandbox_indicator=""
if [ "$sandbox_enabled" = "true" ]; then
    sandbox_indicator="\e[1;33m[SANDBOX]\e[0m "
fi

# Reasoning effort level: only present for models that support the effort
# parameter, and it reflects the live session value -- so a mid-session /effort
# change (or fast-mode toggle) shows up on the next refresh rather than being a
# frozen session-start snapshot.  Absent -> show nothing.  Colored green (low)
# up through red (max) to echo the cost-tier coloring: more effort means more
# reasoning tokens.
effort_level=$(echo "$input" | jq -r '.effort.level // ""')
effort_display=""
if [ -n "$effort_level" ]; then
    case "$effort_level" in
        low)    effort_color="\e[32m"   ;;  # green
        medium) effort_color="\e[36m"   ;;  # cyan
        high)   effort_color="\e[33m"   ;;  # yellow
        xhigh)  effort_color="\e[1;35m" ;;  # bright magenta
        max)    effort_color="\e[1;31m" ;;  # bright red
        *)      effort_color=""         ;;  # unknown future value: no color
    esac
    effort_display=" ${effort_color}${effort_level}\e[0m"
fi

# Output compact status line with cost and the free-space gauge.  Effort (when
# present) rides right after the model name, since it is a property of how the
# model runs.
printf "%b%b %s%b | %s | %s | %b | [%s]\n" \
    "$sandbox_indicator" "$cost_warning" "$model_short" "$effort_display" \
    "$project_name" "$cost_display" "$free_display" "$session_display"
