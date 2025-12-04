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
    C_SEGMENT_5="216"
    C_SEGMENT_6="211"
    C_TEXT_LIGHT="255"
    C_TEXT_DARK="232"
fi

# Set defaults for extended segments if not defined by theme
C_SEGMENT_5="${C_SEGMENT_5:-$C_SEGMENT_4}"
C_SEGMENT_6="${C_SEGMENT_6:-$C_SEGMENT_4}"

# Model text color - defaults to light for dark backgrounds, can be overridden
C_MODEL_TEXT="${C_MODEL_TEXT:-$C_TEXT_LIGHT}"

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

# Git branch and stats (if in repo)
GIT_BRANCH=""
GIT_ADDS=""
GIT_DELS=""
if [ -n "$CURRENT_DIR" ] && [ -d "$CURRENT_DIR/.git" ]; then
    GIT_BRANCH=$(cd "$CURRENT_DIR" 2>/dev/null && git branch --show-current 2>/dev/null)
    # Get additions and deletions from git diff --stat
    if [ -n "$GIT_BRANCH" ]; then
        GIT_STAT=$(cd "$CURRENT_DIR" 2>/dev/null && git diff --shortstat 2>/dev/null)
        if [ -n "$GIT_STAT" ]; then
            GIT_ADDS=$(echo "$GIT_STAT" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
            GIT_DELS=$(echo "$GIT_STAT" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
        fi
    fi
fi

# Build statusline with COMBINED escape codes (critical for Claude Code!)
# Pattern: \033[48;5;BG;38;5;FGm (background AND foreground in ONE sequence)

OUT=""

# Rounded left cap (surface color on terminal bg)
OUT+="\033[38;5;${C_SURFACE_BG}m${PL_LEFT}\033[0m"

# Segment 1: Model (surface bg, model text color for proper contrast)
OUT+="\033[48;5;${C_SURFACE_BG};38;5;${C_MODEL_TEXT};1m ${MODEL} \033[0m"
# Arrow: surface color on segment 1 background
OUT+="\033[48;5;${C_SEGMENT_1};38;5;${C_SURFACE_BG}m${PL}\033[0m"

# Segment 2: Full path (segment 1 bg, dark text)
OUT+="\033[48;5;${C_SEGMENT_1};38;5;${C_TEXT_DARK};1m  ${FULL_PATH} \033[0m"

# Track last segment for arrow coloring
LAST_SEG="${C_SEGMENT_1}"

# Git branch segment
if [ -n "$GIT_BRANCH" ]; then
    # Arrow: last segment on segment 2
    OUT+="\033[48;5;${C_SEGMENT_2};38;5;${LAST_SEG}m${PL}\033[0m"
    # Segment 3: Git with branch icon (segment 2 bg, dark text)
    OUT+="\033[48;5;${C_SEGMENT_2};38;5;${C_TEXT_DARK};1m ${GIT_BRANCH_ICON} ${GIT_BRANCH} \033[0m"
    LAST_SEG="${C_SEGMENT_2}"

    # Git stats segment (if there are changes)
    if [ -n "$GIT_ADDS" ] || [ -n "$GIT_DELS" ]; then
        GIT_ADDS="${GIT_ADDS:-0}"
        GIT_DELS="${GIT_DELS:-0}"
        # Arrow: segment 2 on segment 3
        OUT+="\033[48;5;${C_SEGMENT_3};38;5;${LAST_SEG}m${PL}\033[0m"
        # Segment 4: Git stats (segment 3 bg, dark text)
        OUT+="\033[48;5;${C_SEGMENT_3};38;5;${C_TEXT_DARK};1m +${GIT_ADDS} -${GIT_DELS} \033[0m"
        LAST_SEG="${C_SEGMENT_3}"
    fi
fi

# Arrow to cost segment
OUT+="\033[48;5;${C_SEGMENT_4};38;5;${LAST_SEG}m${PL}\033[0m"

# Segment: Cost (segment 4 bg, dark text)
OUT+="\033[48;5;${C_SEGMENT_4};38;5;${C_TEXT_DARK};1m  ${COST_DISPLAY} \033[0m"
# Arrow: segment 4 on segment 5
OUT+="\033[48;5;${C_SEGMENT_5};38;5;${C_SEGMENT_4}m${PL}\033[0m"

# Segment: Time (segment 5 bg, dark text)
OUT+="\033[48;5;${C_SEGMENT_5};38;5;${C_TEXT_DARK};1m ${CURRENT_TIME} \033[0m"
# Arrow: segment 5 on segment 6
OUT+="\033[48;5;${C_SEGMENT_6};38;5;${C_SEGMENT_5}m${PL}\033[0m"

# Segment: Session duration (segment 6 bg, dark text)
OUT+="\033[48;5;${C_SEGMENT_6};38;5;${C_TEXT_DARK};1m ${SESSION_TIME} \033[0m"
# Rounded right cap (segment 6 on terminal bg) + trailing space for separation
OUT+="\033[38;5;${C_SEGMENT_6}m${PL_RIGHT}\033[0m "

printf "%b" "$OUT"
