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
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // ""')

# Get project name from current directory
if [ -n "$current_dir" ]; then
    project_name=$(basename "$current_dir")
else
    project_name=$(basename "$(pwd)")
fi

# Parse transcript file for token usage and calculate costs PER MODEL
total_input_tokens=0
total_output_tokens=0
total_cost=0.00
token_display="0"
cost_display="\$0.00"

# Cost accumulators per model - separate cache types
opus4_input=0
opus4_cache_creation=0
opus4_cache_read=0
opus4_cache_write=0
opus4_output=0
sonnet4_input=0
sonnet4_cache_creation=0
sonnet4_cache_read=0
sonnet4_cache_write=0
sonnet4_output=0
sonnet35_input=0
sonnet35_cache_creation=0
sonnet35_cache_read=0
sonnet35_cache_write=0
sonnet35_output=0
haiku_input=0
haiku_cache_creation=0
haiku_cache_read=0
haiku_cache_write=0
haiku_output=0

if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    # Parse each message and track costs by model
    while IFS= read -r line; do
        if echo "$line" | jq -e '.message.usage' >/dev/null 2>&1; then
            # Get token counts
            input_tokens=$(echo "$line" | jq -r '.message.usage.input_tokens // 0')
            cache_creation_tokens=$(echo "$line" | jq -r '.message.usage.cache_creation_input_tokens // 0')
            cache_read_tokens=$(echo "$line" | jq -r '.message.usage.cache_read_input_tokens // 0')
            cache_write_tokens=$(echo "$line" | jq -r '.message.usage.cache_write_input_tokens // 0')
            output_tokens=$(echo "$line" | jq -r '.message.usage.output_tokens // 0')
            message_model=$(echo "$line" | jq -r '.message.model // ""')

            # Calculate total input tokens for this message (for display only)
            msg_input_tokens=$((input_tokens + cache_creation_tokens + cache_read_tokens + cache_write_tokens))

            # Add to overall totals
            total_input_tokens=$((total_input_tokens + msg_input_tokens))
            total_output_tokens=$((total_output_tokens + output_tokens))

            # Accumulate tokens by model - separate cache types for proper pricing
            case "$message_model" in
                *"opus-4"*|*"claude-opus-4"*)
                    opus4_input=$((opus4_input + input_tokens))
                    opus4_cache_creation=$((opus4_cache_creation + cache_creation_tokens))
                    opus4_cache_read=$((opus4_cache_read + cache_read_tokens))
                    opus4_cache_write=$((opus4_cache_write + cache_write_tokens))
                    opus4_output=$((opus4_output + output_tokens))
                    ;;
                *"sonnet-4"*|*"claude-sonnet-4"*)
                    sonnet4_input=$((sonnet4_input + input_tokens))
                    sonnet4_cache_creation=$((sonnet4_cache_creation + cache_creation_tokens))
                    sonnet4_cache_read=$((sonnet4_cache_read + cache_read_tokens))
                    sonnet4_cache_write=$((sonnet4_cache_write + cache_write_tokens))
                    sonnet4_output=$((sonnet4_output + output_tokens))
                    ;;
                *"sonnet"*|*"claude-3-5-sonnet"*)
                    sonnet35_input=$((sonnet35_input + input_tokens))
                    sonnet35_cache_creation=$((sonnet35_cache_creation + cache_creation_tokens))
                    sonnet35_cache_read=$((sonnet35_cache_read + cache_read_tokens))
                    sonnet35_cache_write=$((sonnet35_cache_write + cache_write_tokens))
                    sonnet35_output=$((sonnet35_output + output_tokens))
                    ;;
                *"haiku"*)
                    haiku_input=$((haiku_input + input_tokens))
                    haiku_cache_creation=$((haiku_cache_creation + cache_creation_tokens))
                    haiku_cache_read=$((haiku_cache_read + cache_read_tokens))
                    haiku_cache_write=$((haiku_cache_write + cache_write_tokens))
                    haiku_output=$((haiku_output + output_tokens))
                    ;;
            esac
        fi
    done < "$transcript_path"

    # Calculate costs per model (per 1M tokens)
    opus4_cost=0
    sonnet4_cost=0
    sonnet35_cost=0
    haiku_cost=0

    # Opus 4: $15 input, $75 output per 1M tokens
    # Cache pricing: 25% for creation, 10% for reads, 25% for writes
    if [ $opus4_input -gt 0 ] || [ $opus4_cache_creation -gt 0 ] || [ $opus4_cache_read -gt 0 ] || [ $opus4_cache_write -gt 0 ] || [ $opus4_output -gt 0 ]; then
        opus4_cost=$(echo "scale=6; ($opus4_input * 15 + $opus4_cache_creation * 3.75 + $opus4_cache_read * 1.5 + $opus4_cache_write * 3.75 + $opus4_output * 75) / 1000000" | bc -l 2>/dev/null || echo "0")
    fi

    # Sonnet 4: $3 input, $15 output per 1M tokens
    # Cache pricing: 25% for creation, 10% for reads, 25% for writes
    if [ $sonnet4_input -gt 0 ] || [ $sonnet4_cache_creation -gt 0 ] || [ $sonnet4_cache_read -gt 0 ] || [ $sonnet4_cache_write -gt 0 ] || [ $sonnet4_output -gt 0 ]; then
        sonnet4_cost=$(echo "scale=6; ($sonnet4_input * 3 + $sonnet4_cache_creation * 0.75 + $sonnet4_cache_read * 0.3 + $sonnet4_cache_write * 0.75 + $sonnet4_output * 15) / 1000000" | bc -l 2>/dev/null || echo "0")
    fi

    # Sonnet 3.5: $3 input, $15 output per 1M tokens
    # Cache pricing: 25% for creation, 10% for reads, 25% for writes
    if [ $sonnet35_input -gt 0 ] || [ $sonnet35_cache_creation -gt 0 ] || [ $sonnet35_cache_read -gt 0 ] || [ $sonnet35_cache_write -gt 0 ] || [ $sonnet35_output -gt 0 ]; then
        sonnet35_cost=$(echo "scale=6; ($sonnet35_input * 3 + $sonnet35_cache_creation * 0.75 + $sonnet35_cache_read * 0.3 + $sonnet35_cache_write * 0.75 + $sonnet35_output * 15) / 1000000" | bc -l 2>/dev/null || echo "0")
    fi

    # Haiku: $0.25 input, $1.25 output per 1M tokens
    # Cache pricing: 25% for creation, 10% for reads, 25% for writes
    if [ $haiku_input -gt 0 ] || [ $haiku_cache_creation -gt 0 ] || [ $haiku_cache_read -gt 0 ] || [ $haiku_cache_write -gt 0 ] || [ $haiku_output -gt 0 ]; then
        haiku_cost=$(echo "scale=6; ($haiku_input * 0.25 + $haiku_cache_creation * 0.0625 + $haiku_cache_read * 0.025 + $haiku_cache_write * 0.0625 + $haiku_output * 1.25) / 1000000" | bc -l 2>/dev/null || echo "0")
    fi

    # Sum total cost across all models
    total_cost=$(echo "scale=6; $opus4_cost + $sonnet4_cost + $sonnet35_cost + $haiku_cost" | bc -l 2>/dev/null || echo "0")

    # Format token display (K for thousands, M for millions)
    total_tokens=$((total_input_tokens + total_output_tokens))
    if [ $total_tokens -ge 1000000 ]; then
        token_display=$(echo "scale=1; $total_tokens / 1000000" | bc -l 2>/dev/null || echo "0")M
    elif [ $total_tokens -ge 1000 ]; then
        token_display=$(echo "scale=1; $total_tokens / 1000" | bc -l 2>/dev/null || echo "0")K
    else
        token_display="$total_tokens"
    fi

    # Format cost display
    if (( $(echo "$total_cost >= 0.01" | bc -l 2>/dev/null || echo 0) )); then
        cost_display=$(printf "\$%.4f" "$total_cost" 2>/dev/null || echo "\$0.00")
    else
        cost_display=$(printf "\$%.6f" "$total_cost" 2>/dev/null || echo "\$0.00")
    fi
fi

# Set cost warning and model display based on actual model ID
case "$model_id" in
    *"opus-4"*|*"opusplan"*|*"claude-4-opus"*)
        cost_warning="\e[1;31mEXPENSIVE\e[0m"
        model_short="Opus 4"
        ;;
    *"sonnet-4"*|*"claude-sonnet-4"*)
        cost_warning="\e[1;36mMEDIUM\e[0m"
        model_short="Sonnet 4"
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

# Output compact status line with cost and token usage
printf "%b %s | %s | %s | %s tokens\n" "$cost_warning" "$model_short" "$project_name" "$cost_display" "$token_display"
