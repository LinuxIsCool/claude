#!/bin/bash

# Claude Code Powerline Status Line with Theme Support
# Themes stored in ~/.claude/themes/

# Read JSON input from stdin
INPUT=$(cat)

# Powerline glyphs - using hex bytes for reliability
PL=$'\xee\x82\xb0'      # U+E0B0 Arrow separator
PL_LEFT=$'\xee\x82\xb6'  # U+E0B6 Left rounded cap
PL_RIGHT=$'\xee\x82\xb4' # U+E0B4 Right rounded cap
GIT_BRANCH_ICON=$'\xee\x82\xa0'  # U+E0A0 Git branch icon

# Load theme
THEME_DIR="$HOME/.claude/themes"
THEME_CONF="$HOME/.claude/statusline-theme.conf"
THEME_NAME_FILE=$(cat "$THEME_CONF" 2>/dev/null || echo "catppuccin-mocha")
THEME_FILE="$THEME_DIR/${THEME_NAME_FILE}.sh"

# Source theme or use defaults
if [ -f "$THEME_FILE" ]; then
    source "$THEME_FILE"
else
    # Fallback: Catppuccin Mocha
    THEME_NAME="Catppuccin Mocha"
    C_SURFACE_BG="238"
    C_SEGMENT_1="216"
    C_SEGMENT_2="157"
    C_SEGMENT_3="117"
    C_SEGMENT_4="218"
    C_TEXT_LIGHT="255"
    C_TEXT_DARK="232"
fi

# Extract data from JSON
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // .model.id // "Claude"' 2>/dev/null)
CURRENT_DIR=$(echo "$INPUT" | jq -r '.workspace.current_dir // .cwd // ""' 2>/dev/null)
# Use full path, replace $HOME with ~
FULL_PATH="${CURRENT_DIR/#$HOME/\~}"
# Truncate path if too long (keep last 25 chars with … prefix)
if [ ${#FULL_PATH} -gt 28 ]; then
    FULL_PATH="…${FULL_PATH: -25}"
fi
TOTAL_COST=$(echo "$INPUT" | jq -r '.cost.total_cost_usd // 0' 2>/dev/null)

# Format cost
if [ "$(echo "$TOTAL_COST >= 1" | bc -l 2>/dev/null)" = "1" ]; then
    COST_DISPLAY=$(printf "\$%.2f" "$TOTAL_COST")
elif [ "$(echo "$TOTAL_COST > 0" | bc -l 2>/dev/null)" = "1" ]; then
    COST_DISPLAY=$(printf "\$%.4f" "$TOTAL_COST")
else
    COST_DISPLAY="\$0.00"
fi

# Clock without seconds
CURRENT_TIME=$(date +"%H:%M")

# Session duration from Claude (in milliseconds)
DURATION_MS=$(echo "$INPUT" | jq -r '.cost.total_duration_ms // 0' 2>/dev/null)
if [ "$DURATION_MS" != "0" ] && [ "$DURATION_MS" != "null" ] && [ -n "$DURATION_MS" ]; then
    DURATION_SEC=$((DURATION_MS / 1000))
    DURATION_MIN=$((DURATION_SEC / 60))
    DURATION_HR=$((DURATION_MIN / 60))
    DURATION_MIN_REM=$((DURATION_MIN % 60))
    DURATION_SEC_REM=$((DURATION_SEC % 60))
    if [ "$DURATION_HR" -gt 0 ]; then
        SESSION_TIME="${DURATION_HR}h${DURATION_MIN_REM}m"
    elif [ "$DURATION_MIN" -gt 0 ]; then
        SESSION_TIME="${DURATION_MIN}m${DURATION_SEC_REM}s"
    else
        SESSION_TIME="${DURATION_SEC}s"
    fi
else
    SESSION_TIME="0s"
fi

# Git branch (if in repo)
GIT_BRANCH=""
if [ -n "$CURRENT_DIR" ] && [ -d "$CURRENT_DIR/.git" ]; then
    GIT_BRANCH=$(cd "$CURRENT_DIR" 2>/dev/null && git branch --show-current 2>/dev/null)
fi

# Build statusline with COMBINED escape codes (critical for Claude Code!)
# Pattern: \033[48;5;BG;38;5;FGm (background AND foreground in ONE sequence)

OUT=""

# Rounded left cap (surface color on terminal bg)
OUT+="\033[38;5;${C_SURFACE_BG}m${PL_LEFT}\033[0m"

# Segment 1: Model (dark surface bg, light text)
OUT+="\033[48;5;${C_SURFACE_BG};38;5;${C_TEXT_LIGHT};1m ${MODEL} \033[0m"
# Arrow: surface color on segment 1 background
OUT+="\033[48;5;${C_SEGMENT_1};38;5;${C_SURFACE_BG}m${PL}\033[0m"

# Segment 2: Full path (segment 1 bg, dark text)
OUT+="\033[48;5;${C_SEGMENT_1};38;5;${C_TEXT_DARK};1m  ${FULL_PATH} \033[0m"

# Next segment depends on git
if [ -n "$GIT_BRANCH" ]; then
    # Arrow: segment 1 on segment 2
    OUT+="\033[48;5;${C_SEGMENT_2};38;5;${C_SEGMENT_1}m${PL}\033[0m"
    # Segment 3: Git with branch icon (segment 2 bg, dark text)
    OUT+="\033[48;5;${C_SEGMENT_2};38;5;${C_TEXT_DARK};1m ${GIT_BRANCH_ICON} ${GIT_BRANCH} \033[0m"
    # Arrow: segment 2 on segment 3
    OUT+="\033[48;5;${C_SEGMENT_3};38;5;${C_SEGMENT_2}m${PL}\033[0m"
else
    # Arrow: segment 1 on segment 3
    OUT+="\033[48;5;${C_SEGMENT_3};38;5;${C_SEGMENT_1}m${PL}\033[0m"
fi

# Segment 4: Cost (segment 3 bg, dark text)
OUT+="\033[48;5;${C_SEGMENT_3};38;5;${C_TEXT_DARK};1m  ${COST_DISPLAY} \033[0m"
# Arrow: segment 3 on segment 4
OUT+="\033[48;5;${C_SEGMENT_4};38;5;${C_SEGMENT_3}m${PL}\033[0m"

# Segment 5: Time and Session duration (segment 4 bg, dark text)
OUT+="\033[48;5;${C_SEGMENT_4};38;5;${C_TEXT_DARK};1m ${CURRENT_TIME} 🕐 ${SESSION_TIME} \033[0m"
# Rounded right cap (segment 4 on terminal bg) + trailing space for separation
OUT+="\033[38;5;${C_SEGMENT_4}m${PL_RIGHT}\033[0m "

printf "%b" "$OUT"
