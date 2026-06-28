#!/bin/bash
# Runs when the Moonlight client disconnects (Sunshine global_prep_cmd "undo").
#
# Responsibilities (in order):
#   1. Resume hypridle (paused in sunshine-connect.sh).
#   2. Turn the physical monitor back on (DPMS on DP-1).
#   3. Migrate workspaces from HEADLESS back to DP-1.
#
# The HEADLESS monitor itself is NOT removed — it persists for the whole
# session so Sunshine's cached output_name stays valid for the next connect.

LOG="$HOME/.local/share/sunshine-headless.log"

# Detect Hyprland config provider
HYPR_CONF_PROVIDER=legacy
if [ "$(hyprctl dispatch 'hl.dsp.no_op()')" = "ok" ] ; then
    HYPR_CONF_PROVIDER=lua
fi

# --- 1. resume hypridle -----------------------------------------------------
pkill -CONT -x hypridle 2>/dev/null

HEADLESS=$(hyprctl monitors -j | python3 -c \
    "import sys,json; ms=[m['name'] for m in json.load(sys.stdin) if 'HEADLESS' in m['name']]; print(ms[0] if ms else '')")

# --- 2. turn the physical monitor back on -----------------------------------
if [ $HYPR_CONF_PROVIDER = "lua" ] ; then
    hyprctl dispatch 'hl.dsp.dpms({ action="on", monitor="DP-1"})'
else
    hyprctl dispatch dpms on DP-1
fi

# --- 3. re-pin workspaces 1-10 back to DP-1 then migrate them --------------
# Mirror of connect.sh: re-pin BEFORE moving so the workspaces stay on DP-1
# afterwards instead of being pulled back to HEADLESS by leftover rules.
if [ $HYPR_CONF_PROVIDER = "lua" ] ; then
    hyprctl eval 'for ws = 1,10 do hl.workspace_rule({workspace=ws, monitor="DP-1", persistent=false}) end' >/dev/null 2>&1
else
    for ws in 1 2 3 4 5 6 7 8 9 10; do
        hyprctl keyword workspace "$ws, monitor:DP-1, persistent:false" >/dev/null 2>&1
    done
fi

if [ -n "$HEADLESS" ]; then
    WS_IDS=$(hyprctl workspaces -j | python3 -c \
        "import sys,json; [print(w['id']) for w in json.load(sys.stdin) if w['monitor']=='$HEADLESS' and w['id']>0 and w['id']!=11]")

    for id in $WS_IDS; do
        if [ $HYPR_CONF_PROVIDER = "lua" ] ; then
            hyprctl dispatch "hl.dsp.workspace.move({ workspace=\"$id\", monitor=\"DP-1\" })"
        else
            hyprctl dispatch moveworkspacetomonitor "$id" DP-1
        fi
    done
fi


if [ $HYPR_CONF_PROVIDER = "lua" ] ; then
    hyprctl dispatch 'hl.dsp.focus({ monitor="DP-1"})'
else
    hyprctl dispatch focusmonitor DP-1
fi

echo "$(date -Iseconds) Client disconnected, workspaces returned to DP-1" >> "$LOG"
