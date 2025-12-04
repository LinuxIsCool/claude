#!/bin/bash
# Cycle through Claude Code statusline themes

THEME_DIR="$HOME/.claude/themes"
THEME_CONF="$HOME/.claude/statusline-theme.conf"

# Get sorted list of themes (strip .sh extension)
themes=($(ls "$THEME_DIR"/*.sh 2>/dev/null | xargs -n1 basename | sed 's/\.sh$//' | sort))

# Get current theme
current=$(cat "$THEME_CONF" 2>/dev/null || echo "${themes[0]}")

# Find next theme
next="${themes[0]}"
for i in "${!themes[@]}"; do
    if [[ "${themes[$i]}" == "$current" ]]; then
        next_idx=$(( (i + 1) % ${#themes[@]} ))
        next="${themes[$next_idx]}"
        break
    fi
done

# Write new theme
printf '%s' "$next" > "$THEME_CONF"
echo "$next"
